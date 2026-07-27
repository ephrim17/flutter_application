/* eslint-disable max-len, require-jsdoc */
import * as admin from "firebase-admin";
import {logger} from "firebase-functions";
import {defineSecret, defineString} from "firebase-functions/params";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

const youtubeApiKey = defineSecret("YOUTUBE_API_KEY");
const youtubeWebhookCallbackUrl = defineString("YOUTUBE_WEBHOOK_CALLBACK_URL");
const youtubeHubUrl = "https://pubsubhubbub.appspot.com/subscribe";
const youtubeFeedBaseUrl = "https://www.youtube.com/feeds/videos.xml";

type LiveChurchConfigData = {
  enabled?: boolean;
  notifyWhenLive?: boolean;
  youtubeChannelId?: string;
};

export const notifyChurchWhenYouTubeLive = onDocumentWritten(
  {
    document: "churches/{churchId}/live_church/status",
    region: "us-central1",
  },
  async (event) => {
    const after = event.data?.after.data();
    const statusRef = event.data?.after.ref;
    const videoId = String(after?.videoId ?? "").trim();
    if (!statusRef || after?.isLive !== true || !videoId) return;

    const churchId = String(event.params.churchId);
    const configRef = statusRef.parent.doc("config");
    const shouldNotify = await admin.firestore().runTransaction(
      async (transaction) => {
        const [config, currentStatus] = await Promise.all([
          transaction.get(configRef),
          transaction.get(statusRef),
        ]);
        if (config.data()?.notifyWhenLive !== true) return false;
        if (currentStatus.data()?.notifiedVideoId == videoId) return false;
        transaction.set(statusRef, {
          notifiedVideoId: videoId,
          notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
        return true;
      },
    );
    if (!shouldNotify) return;

    const title = String(after?.title ?? "").trim();
    await admin.messaging().send({
      topic: `church_${churchId}`,
      notification: {
        title: "Church is live",
        body: title ?
          `${title} is live now. Tap to watch.` :
          "The church service is live now. Tap to watch.",
      },
      data: {
        kind: "live_church",
        churchId,
        videoId,
        tab: "for_you",
      },
      android: {
        notification: {
          channelId: "church_messages",
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: {sound: "default"},
        },
      },
    });
  },
);

type YouTubeVideo = {
  id?: string;
  snippet?: {
    title?: string;
    channelId?: string;
  };
  status?: {
    embeddable?: boolean;
    privacyStatus?: string;
  };
  liveStreamingDetails?: {
    actualStartTime?: string;
    actualEndTime?: string;
    scheduledStartTime?: string;
  };
};

export const syncYouTubeChannelSubscription = onDocumentWritten(
  {
    document: "churches/{churchId}/live_church/config",
    region: "us-central1",
    secrets: [youtubeApiKey],
  },
  async (event) => {
    const before = event.data?.before.data() as
      LiveChurchConfigData | undefined;
    const after = event.data?.after.data() as LiveChurchConfigData | undefined;
    const oldChannelId = readChannelId(before);
    const newChannelId = readChannelId(after);

    if (oldChannelId && oldChannelId != newChannelId) {
      await updateHubSubscription(oldChannelId, "unsubscribe");
    }
    if (oldChannelId != newChannelId || after?.enabled !== true) {
      const statusRef = event.data?.after.ref.parent.doc("status") ??
        event.data?.before.ref.parent.doc("status");
      if (statusRef) await statusRef.set(endedStatus(), {merge: true});
    }
    if (newChannelId && after?.enabled === true) {
      await updateHubSubscription(newChannelId, "subscribe");
      const liveVideo = await findCurrentLiveVideo(newChannelId);
      if (liveVideo) {
        await publishVideoState(newChannelId, liveVideo);
      }
    } else if (newChannelId) {
      await updateHubSubscription(newChannelId, "unsubscribe");
    }
  },
);

export const renewYouTubeChannelSubscriptions = onSchedule(
  {
    schedule: "every day 03:00",
    timeZone: "UTC",
    region: "us-central1",
  },
  async () => {
    const configs = await admin.firestore().collectionGroup("live_church")
      .where("enabled", "==", true)
      .get();
    const channelIds = new Set(
      configs.docs
        .filter((doc) => doc.id == "config")
        .map((doc) => readChannelId(doc.data()))
        .filter((value): value is string => value != null),
    );

    for (const channelId of channelIds) {
      try {
        await updateHubSubscription(channelId, "subscribe");
      } catch (error) {
        logger.error("Failed to renew YouTube channel subscription.", {
          channelId,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  },
);

export const youtubeLiveWebhook = onRequest(
  {
    region: "us-central1",
    cors: false,
    secrets: [youtubeApiKey],
  },
  async (req, res) => {
    if (req.method == "GET") {
      const challenge = String(req.query["hub.challenge"] ?? "");
      if (!challenge) {
        res.status(400).send("Missing hub.challenge");
        return;
      }
      res.status(200).type("text/plain").send(challenge);
      return;
    }

    if (req.method != "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    // Acknowledge empty unsubscribe/deletion notifications.
    const xml = req.rawBody?.toString("utf8") ?? "";
    const videoId = readXmlValue(xml, "yt:videoId");
    const channelId = readXmlValue(xml, "yt:channelId");
    if (!videoId || !channelId) {
      res.status(204).send();
      return;
    }

    try {
      const [video] = await fetchYouTubeVideos([videoId]);
      if (video) await publishVideoState(channelId, video);
      res.status(204).send();
    } catch (error) {
      logger.error("Failed to process YouTube push notification.", {
        channelId,
        videoId,
        error: error instanceof Error ? error.message : String(error),
      });
      res.status(500).send("Unable to process notification");
    }
  },
);

export const refreshKnownYouTubeBroadcasts = onSchedule(
  {
    schedule: "every 1 minutes",
    region: "us-central1",
    secrets: [youtubeApiKey],
  },
  async () => {
    const statuses = await admin.firestore().collectionGroup("live_church")
      .where("monitoring", "==", true)
      .get();
    const statusDocs = statuses.docs.filter((doc) => doc.id == "status");
    const videoIds = [...new Set(statusDocs
      .map((doc) => String(doc.data().videoId ?? "").trim())
      .filter(Boolean))];

    for (let index = 0; index < videoIds.length; index += 50) {
      const videos = await fetchYouTubeVideos(videoIds.slice(index, index + 50));
      const videoById = new Map(videos.map((video) => [video.id, video]));
      const batch = admin.firestore().batch();

      for (const statusDoc of statusDocs) {
        const videoId = String(statusDoc.data().videoId ?? "").trim();
        const video = videoById.get(videoId);
        if (!video) {
          batch.set(statusDoc.ref, endedStatus(), {merge: true});
          continue;
        }
        batch.set(statusDoc.ref, statusFromVideo(video), {merge: true});
      }
      await batch.commit();
    }
  },
);

async function updateHubSubscription(
  channelId: string,
  mode: "subscribe" | "unsubscribe",
): Promise<void> {
  const callbackUrl = youtubeWebhookCallbackUrl.value().trim();
  if (!callbackUrl) {
    throw new Error("YOUTUBE_WEBHOOK_CALLBACK_URL is not configured.");
  }
  const topicUrl = `${youtubeFeedBaseUrl}?channel_id=${channelId}`;
  const body = new URLSearchParams({
    "hub.callback": callbackUrl,
    "hub.topic": topicUrl,
    "hub.verify": "async",
    "hub.mode": mode,
    "hub.lease_seconds": "864000",
  });
  const response = await fetch(youtubeHubUrl, {
    method: "POST",
    headers: {"content-type": "application/x-www-form-urlencoded"},
    body,
  });
  if (!response.ok) {
    throw new Error(`YouTube hub returned HTTP ${response.status}.`);
  }
}

async function fetchYouTubeVideos(ids: string[]): Promise<YouTubeVideo[]> {
  if (ids.length == 0) return [];
  const url = new URL("https://www.googleapis.com/youtube/v3/videos");
  url.searchParams.set("part", "snippet,status,liveStreamingDetails");
  url.searchParams.set("id", ids.join(","));
  url.searchParams.set("key", youtubeApiKey.value());
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`YouTube API returned HTTP ${response.status}.`);
  }
  const payload = await response.json() as {items?: YouTubeVideo[]};
  return payload.items ?? [];
}

async function findCurrentLiveVideo(
  channelId: string,
): Promise<YouTubeVideo | null> {
  const url = new URL("https://www.googleapis.com/youtube/v3/search");
  url.searchParams.set("part", "snippet");
  url.searchParams.set("channelId", channelId);
  url.searchParams.set("eventType", "live");
  url.searchParams.set("type", "video");
  url.searchParams.set("maxResults", "1");
  url.searchParams.set("key", youtubeApiKey.value());
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`YouTube live search returned HTTP ${response.status}.`);
  }
  const payload = await response.json() as {
    items?: Array<{id?: {videoId?: string}}>;
  };
  const videoId = payload.items?.[0]?.id?.videoId;
  if (!videoId) return null;
  const [video] = await fetchYouTubeVideos([videoId]);
  return video ?? null;
}

async function publishVideoState(
  channelId: string,
  video: YouTubeVideo,
): Promise<void> {
  if (!video.liveStreamingDetails) return;
  const configs = await admin.firestore().collectionGroup("live_church")
    .where("youtubeChannelId", "==", channelId)
    .get();
  const batch = admin.firestore().batch();
  for (const config of configs.docs.filter(
    (doc) => doc.id == "config" && doc.data().enabled === true,
  )) {
    batch.set(config.ref.parent.doc("status"), statusFromVideo(video), {
      merge: true,
    });
  }
  await batch.commit();
}

function statusFromVideo(video: YouTubeVideo): Record<string, unknown> {
  const details = video.liveStreamingDetails;
  const isLive = Boolean(
    details?.actualStartTime &&
    !details.actualEndTime &&
    video.status?.privacyStatus == "public",
  );
  const isUpcoming = Boolean(
    details?.scheduledStartTime &&
    !details.actualStartTime &&
    !details.actualEndTime,
  );
  return {
    isLive,
    canEmbed: video.status?.embeddable !== false,
    monitoring: isLive || isUpcoming,
    videoId: video.id ?? "",
    title: video.snippet?.title ?? "",
    youtubeChannelId: video.snippet?.channelId ?? "",
    startedAt: details?.actualStartTime ?
      admin.firestore.Timestamp.fromDate(new Date(details.actualStartTime)) :
      null,
    scheduledStartAt: details?.scheduledStartTime ?
      admin.firestore.Timestamp.fromDate(new Date(details.scheduledStartTime)) :
      null,
    checkedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function endedStatus(): Record<string, unknown> {
  return {
    isLive: false,
    monitoring: false,
    checkedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function readChannelId(data?: LiveChurchConfigData): string | null {
  const value = String(data?.youtubeChannelId ?? "").trim();
  return /^UC[A-Za-z0-9_-]{20,}$/.test(value) ? value : null;
}

function readXmlValue(xml: string, tag: string): string | null {
  const escapedTag = tag.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = new RegExp(
    `<${escapedTag}>([^<]+)</${escapedTag}>`,
    "i",
  ).exec(xml);
  return match?.[1]?.trim() || null;
}
