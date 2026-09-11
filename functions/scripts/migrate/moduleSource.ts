export type ModuleSource = "global" | "church";

interface ModuleIndex {
  /** moduleId -> source, for every module in this church + global. */
  moduleSource: Map<string, ModuleSource>;
  /** sectionId -> {moduleId, source}, for the same set of modules. */
  sectionOwner: Map<string, {moduleId: string; source: ModuleSource}>;
}

const globalCache: {moduleSource: Map<string, ModuleSource>;
  sectionOwner: Map<string, {moduleId: string; source: ModuleSource}>} = {
    moduleSource: new Map(),
    sectionOwner: new Map(),
  };
let globalLoaded = false;

/**
 * Loads and indexes the global `learning_modules` collection, once.
 * @param {FirebaseFirestore.Firestore} firestore Target Firestore instance.
 * @return {Promise<void>} Resolves once the global index is populated.
 */
async function loadGlobalModules(
  firestore: FirebaseFirestore.Firestore,
): Promise<void> {
  if (globalLoaded) return;
  const snapshot = await firestore.collection("learning_modules").get();
  indexModules(snapshot.docs, "global", globalCache.moduleSource,
    globalCache.sectionOwner);
  globalLoaded = true;
}

/**
 * Indexes a batch of module docs into the given maps, in place.
 * @param {FirebaseFirestore.QueryDocumentSnapshot[]} docs Module docs.
 * @param {ModuleSource} source Source to tag every module/section with.
 * @param {Map<string, ModuleSource>} moduleSource Module id -> source map,
 * mutated in place.
 * @param {Map<string, {moduleId: string, source: ModuleSource}>}
 * sectionOwner Section id -> owner map, mutated in place.
 * @return {void}
 */
function indexModules(
  docs: FirebaseFirestore.QueryDocumentSnapshot[],
  source: ModuleSource,
  moduleSource: Map<string, ModuleSource>,
  sectionOwner: Map<string, {moduleId: string; source: ModuleSource}>,
): void {
  for (const doc of docs) {
    moduleSource.set(doc.id, source);
    const sections = doc.data()["sections"];
    if (!Array.isArray(sections)) continue;
    for (const section of sections) {
      const sectionId = section && typeof section === "object" ?
        (section as Record<string, unknown>)["id"] :
        null;
      if (typeof sectionId === "string" && sectionId.length > 0) {
        sectionOwner.set(sectionId, {moduleId: doc.id, source});
      }
    }
  }
}

const churchCache = new Map<string, ModuleIndex>();

/**
 * Builds (and caches) the module/section -> source index for one church,
 * merged with the global index. Global modules are visible inside any
 * church (§5.6), so a church's index always includes them.
 * @param {FirebaseFirestore.Firestore} firestore Target Firestore instance.
 * @param {string} churchId Church to index.
 * @return {Promise<ModuleIndex>} The merged module/section index for that
 * church.
 */
export async function loadChurchModuleIndex(
  firestore: FirebaseFirestore.Firestore,
  churchId: string,
): Promise<ModuleIndex> {
  await loadGlobalModules(firestore);
  const cached = churchCache.get(churchId);
  if (cached) return cached;

  const moduleSource = new Map(globalCache.moduleSource);
  const sectionOwner = new Map(globalCache.sectionOwner);
  const snapshot = await firestore
    .collection("churches").doc(churchId)
    .collection("learning_modules").get();
  indexModules(snapshot.docs, "church", moduleSource, sectionOwner);

  const index: ModuleIndex = {moduleSource, sectionOwner};
  churchCache.set(churchId, index);
  return index;
}

/**
 * Resolves a module id to its source, or null if it matches nothing (the
 * module was deleted since the progress/result row was written).
 * @param {ModuleIndex} index Index built by loadChurchModuleIndex.
 * @param {string} moduleId Module id to resolve.
 * @return {ModuleSource | null} The module's source, or null if unknown.
 */
export function resolveModuleSource(
  index: ModuleIndex,
  moduleId: string,
): ModuleSource | null {
  return index.moduleSource.get(moduleId) ?? null;
}

/**
 * Resolves a section id to its owning module id + source, or null.
 * @param {ModuleIndex} index Index built by loadChurchModuleIndex.
 * @param {string} sectionId Section id to resolve.
 * @return {{moduleId: string, source: ModuleSource} | null} The owning
 * module and its source, or null if unknown.
 */
export function resolveSectionOwner(
  index: ModuleIndex,
  sectionId: string,
): {moduleId: string; source: ModuleSource} | null {
  return index.sectionOwner.get(sectionId) ?? null;
}
