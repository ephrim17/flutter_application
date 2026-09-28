/* eslint-disable max-len, require-jsdoc */
import * as admin from "firebase-admin";
import {logger} from "firebase-functions";
import {defineSecret} from "firebase-functions/params";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

const youtubeApiKey = defineSecret("YOUTUBE_API_KEY");

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

/**
 * Puts this church's live card up or takes it down, on an admin's say-so.
 *
 * Going live is manual: YouTube's push feed notifies on a video being
 * published, not on a stream starting, so for a broadcast scheduled ahead of
 * time nothing ever arrived and the card only appeared when an admin re-saved
 * the Live Church settings (which ran the search below as a side effect).
 * That search is now the deliberate action instead of a side effect.
 *
 * Coming down stays automatic: this writes `monitoring: true`, and
 * `refreshKnownYouTubeBroadcasts` re-checks that video every minute for one
 * quota unit — flipping `isLive` on when the stream actually starts, and
 * ending the card when it stops. So an admin can press this before the stream
 * is live and the card still only appears once it is really available.
 */
export const setLiveChurchBroadcast = onCall(
  {region: "us-central1", secrets: [youtubeApiKey]},
  async (request) => {
    const uid = request.auth?.uid;
    const email = String(request.auth?.token?.email ?? "").toLowerCase();
    if (!uid) throw new HttpsError("unauthenticated", "sign-in-required");

    const data = (request.data ?? {}) as Record<string, unknown>;
    const churchId = String(data.churchId ?? "").trim();
    if (!churchId) throw new HttpsError("invalid-argument", "missing-church");
    const stopping = String(data.action ?? "start") == "stop";
    const videoUrl = String(data.videoUrl ?? "").trim();

    await assertChurchAdmin(uid, email, churchId);

    const liveRef = admin.firestore()
      .collection("churches").doc(churchId).collection("live_church");
    const statusRef = liveRef.doc("status");

    if (stopping) {
      await statusRef.set(endedStatus(), {merge: true});
      return {isLive: false, monitoring: false};
    }

    const config = (await liveRef.doc("config").get())
      .data() as LiveChurchConfigData | undefined;
    if (config?.enabled !== true) {
      throw new HttpsError("failed-precondition", "live-church-disabled");
    }

    // An explicit link wins: a stream that is unlisted, or not yet indexed,
    // will not come back from the search but is perfectly playable.
    let video: YouTubeVideo | null = null;
    if (videoUrl) {
      const videoId = parseYouTubeVideoId(videoUrl);
      if (!videoId) throw new HttpsError("invalid-argument", "bad-video-link");
      video = (await fetchYouTubeVideos([videoId]))[0] ?? null;
    } else {
      const channelId = readChannelId(config);
      if (!channelId) {
        throw new HttpsError("failed-precondition", "no-channel");
      }
      video = await findCurrentLiveVideo(channelId);
    }

    if (!video?.liveStreamingDetails) {
      throw new HttpsError("failed-precondition", "no-live-video");
    }

    const status = statusFromVideo(video);
    await statusRef.set(status, {merge: true});
    return {
      isLive: status.isLive === true,
      monitoring: status.monitoring === true,
      videoId: status.videoId,
      title: status.title,
    };
  },
);

/**
 * Throws unless the caller is an admin of this church.
 *
 * Both sides are lowercased: `config/app.admins` stores emails as typed, so a
 * stored "Ephrim17@gmail.com" must still match a token's
 * "ephrim17@gmail.com". Super-admin status deliberately does not qualify —
 * the three authorities in this app stay separate.
 * @param {string} uid The caller's uid.
 * @param {string} email The caller's lowercased email.
 * @param {string} churchId The church being changed.
 * @return {Promise<void>} Resolves when the caller is an admin.
 */
async function assertChurchAdmin(
  uid: string,
  email: string,
  churchId: string,
): Promise<void> {
  const config = await admin.firestore()
    .collection("churches").doc(churchId)
    .collection("config").doc("app").get();
  const admins = config.data()?.admins;
  const isAdmin = Array.isArray(admins) && !!email && admins.some(
    (entry) => typeof entry == "string" && entry.toLowerCase() == email,
  );
  if (!isAdmin) {
    logger.warn("Rejected a non-admin Live Church broadcast change.", {
      churchId, uid,
    });
    throw new HttpsError("permission-denied", "admin-required");
  }
}

/**
 * The video id in a YouTube link, or a bare id, or null.
 * @param {string} input A link the admin pasted, or a bare video id.
 * @return {string | null} The 11-character video id, or null.
 */
export function parseYouTubeVideoId(input: string): string | null {
  const value = input.trim();
  if (/^[A-Za-z0-9_-]{11}$/.test(value)) return value;
  const patterns = [
    /[?&]v=([A-Za-z0-9_-]{11})/,
    /youtu\.be\/([A-Za-z0-9_-]{11})/,
    /youtube\.com\/live\/([A-Za-z0-9_-]{11})/,
    /youtube\.com\/embed\/([A-Za-z0-9_-]{11})/,
    /youtube\.com\/shorts\/([A-Za-z0-9_-]{11})/,
  ];
  for (const pattern of patterns) {
    const match = pattern.exec(value);
    if (match) return match[1];
  }
  return null;
}

/**
 * Takes a live card down when the settings say it should not be showing.
 *
 * It used to do the opposite as well — subscribe to the channel's push feed
 * and search for a live video — which is why re-saving the settings was the
 * only thing that ever made the card appear. Discovery is
 * [setLiveChurchBroadcast]'s job now, so this deliberately never puts a card
 * *up*; it would otherwise contradict an admin who has just taken one down.
 */
export const syncYouTubeChannelSubscription = onDocumentWritten(
  {
    document: "churches/{churchId}/live_church/config",
    region: "us-central1",
  },
  async (event) => {
    const before = event.data?.before.data() as
      LiveChurchConfigData | undefined;
    const after = event.data?.after.data() as LiveChurchConfigData | undefined;
    const oldChannelId = readChannelId(before);
    const newChannelId = readChannelId(after);

    // Switched off, or pointed at a different channel than the card showing.
    const shouldEnd = after?.enabled !== true ||
      (oldChannelId != null && oldChannelId != newChannelId);
    if (!shouldEnd) return;

    const statusRef = event.data?.after.ref.parent.doc("status") ??
      event.data?.before.ref.parent.doc("status");
    if (statusRef) await statusRef.set(endedStatus(), {merge: true});
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

    // Acknowledged and ignored. Going live is an admin action now, so a push
    // must not put a card up that nobody asked for or resurrect one that was
    // just taken down. This stays only so that subscriptions still out there
    // get a clean 204 instead of retries until their leases lapse; nothing
    // renews them any more.
    res.status(204).send();
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

