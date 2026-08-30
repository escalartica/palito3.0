#!/usr/bin/env node
// =============================================================================
// FASE E — MIGRACIÓN DEL HOGAR REAL AL MODELO MULTI-TENANT (grupos)
// =============================================================================
//
// Script de administración de un solo uso. Copia los datos reales del hogar
// desde el modelo antiguo (users/palito-hogar/**, con eme/ceh hardcodeados)
// a un grupo nuevo del modelo actual (groups/{groupId}/**, indexado por uid
// real de Firebase Auth) — SIN tocar ni borrar el árbol antiguo, que queda
// intacto como copia de seguridad.
//
// El grupo migrado se AÑADE a `groupIds` de eme y ceh (no la sustituye) —
// cada uno conserva también su propio grupo personal, creado ya en su
// primer inicio de sesión con el build nuevo (ver AuthService).
//
// REQUISITO PREVIO (bloqueante): eme y ceh deben haber iniciado sesión al
// menos una vez con Sign in with Apple en el build nuevo, para que existan
// sus documentos reales `users/{uid}` (y por tanto su `groupIds`). Sin eso,
// este script no tiene dónde añadir el grupo migrado y se detiene con un
// error explicativo.
//
// USO:
//
//   cd scripts && npm install   (una sola vez)
//
//   # 1) Dry run (por defecto) — solo lee y muestra qué haría, no escribe nada:
//   GOOGLE_APPLICATION_CREDENTIALS=/ruta/a/service-account.json \
//     node migrate_household.mjs \
//       --eme-uid=UID_REAL_DE_EME --eme-name="Eme" \
//       --ceh-uid=UID_REAL_DE_CEH --ceh-name="CeH"
//
//   # 2) Cuando el resumen del dry run tenga sentido, ejecutar de verdad:
//   GOOGLE_APPLICATION_CREDENTIALS=/ruta/a/service-account.json \
//     node migrate_household.mjs --eme-uid=... --eme-name=... \
//       --ceh-uid=... --ceh-name=... --commit
//
// La clave de cuenta de servicio se descarga desde Firebase Console →
// Configuración del proyecto → Cuentas de servicio → Generar nueva clave
// privada. Trátala como una contraseña: no la subas al repositorio.
// =============================================================================

import { readFileSync } from 'node:fs';
import { initializeApp, cert, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const OLD_HOUSEHOLD_DOC_ID = 'palito-hogar';
const NEW_GROUP_ID = 'palito-hogar'; // se reutiliza el mismo id, a propósito

// ── Argumentos de línea de comandos ─────────────────────────────────────────
function parseArgs(argv) {
  const out = { commit: false };
  for (const raw of argv) {
    if (raw === '--commit') {
      out.commit = true;
      continue;
    }
    const match = raw.match(/^--([a-z-]+)=(.*)$/);
    if (match) out[match[1]] = match[2];
  }
  return out;
}

const args = parseArgs(process.argv.slice(2));
const COMMIT = args.commit === true;

const emeUid = args['eme-uid'];
const emeName = args['eme-name'] ?? 'Eme';
const cehUid = args['ceh-uid'];
const cehName = args['ceh-name'] ?? 'CeH';

if (!emeUid || !cehUid) {
  console.error(
    'Faltan --eme-uid y/o --ceh-uid. Consulta el bloque de USO al inicio ' +
      'de este archivo.',
  );
  process.exit(1);
}

// ── Inicialización de Admin SDK ─────────────────────────────────────────────
function initAdminApp() {
  if (args['service-account']) {
    const json = JSON.parse(readFileSync(args['service-account'], 'utf8'));
    return initializeApp({ credential: cert(json) });
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return initializeApp({ credential: applicationDefault() });
  }
  console.error(
    'No hay credenciales. Define GOOGLE_APPLICATION_CREDENTIALS=/ruta/a/' +
      'service-account.json o pasa --service-account=/ruta/a/archivo.json.',
  );
  process.exit(1);
}

initAdminApp();
const db = getFirestore();

console.log(COMMIT ? '⚠️  MODO COMMIT — se va a escribir de verdad.' : 'ℹ️  DRY RUN — no se escribe nada, solo se muestra el plan.');

// ── 1) Leer el árbol antiguo ─────────────────────────────────────────────────
async function readOldTree() {
  const oldRootRef = db.collection('users').doc(OLD_HOUSEHOLD_DOC_ID);
  const oldRootSnap = await oldRootRef.get();

  if (!oldRootSnap.exists) {
    throw new Error(
      `No existe users/${OLD_HOUSEHOLD_DOC_ID} — nada que migrar, o ya se migró.`,
    );
  }

  const [memoriesSnap, locationsSnap, gameHistorySnap] = await Promise.all([
    oldRootRef.collection('memories').get(),
    oldRootRef.collection('locations').get(),
    oldRootRef.collection('game_history').get(),
  ]);

  // El nombre de la colección/documento de stats varió durante el
  // desarrollo (gamerStats/mainStatsDocument vs gamer_stats/main_stats) —
  // se prueban ambas combinaciones conocidas y se usa la que exista.
  const statsCandidates = [
    ['gamerStats', 'mainStatsDocument'],
    ['gamer_stats', 'main_stats'],
  ];
  let statsData = null;
  for (const [coll, doc] of statsCandidates) {
    const snap = await oldRootRef.collection(coll).doc(doc).get();
    if (snap.exists) {
      statsData = snap.data();
      break;
    }
  }

  return {
    rootData: oldRootSnap.data() ?? {},
    memories: memoriesSnap.docs,
    locations: locationsSnap.docs,
    gameHistory: gameHistorySnap.docs,
    statsData,
  };
}

// ── 2) Transformar gamer_stats: {eme:{...}, ceh:{...}} → players/{uid} ──────
//
// El formato antiguo real (visto en el código de esta misma migración,
// GamerFirestoreService._extractPlayersMap) tiene un mapa 'players'/'users'/
// 'comensales' cuando ya se intentó modernizar a mano, pero el dato de
// producción real conocido son dos claves de nivel superior 'eme' y 'ceh'
// (no anidadas bajo ninguna de esas). Se comprueban ambas formas.
function buildNewPlayersMap(statsData) {
  if (!statsData) return {};

  const nestedMap = statsData.players ?? statsData.users ?? statsData.comensales;
  if (nestedMap && typeof nestedMap === 'object') {
    // Ya viene como mapa — se remapean solo las claves 'eme'/'ceh' conocidas;
    // cualquier otra clave que ya sea un uid real se conserva tal cual.
    const players = {};
    for (const [key, value] of Object.entries(nestedMap)) {
      if (key === 'eme') players[emeUid] = value;
      else if (key === 'ceh') players[cehUid] = value;
      else players[key] = value;
    }
    return players;
  }

  const players = {};
  if (statsData.eme) players[emeUid] = statsData.eme;
  if (statsData.ceh) players[cehUid] = statsData.ceh;
  return players;
}

// ── 3) Transformar profileImages: {'0','1','2'} → {uid: url} ───────────────
//
// El índice '2' (antes usado por la pestaña sintética "Team") no tiene
// equivalente en el modelo nuevo — Team no es una cuenta real y no puede
// tener una foto propia — así que se descarta deliberadamente, no es un
// error.
function buildNewProfileImages(rootData) {
  const old = rootData.profileImages ?? {};
  const next = {};
  if (old['0']) next[emeUid] = old['0'];
  if (old['1']) next[cehUid] = old['1'];
  if (old['2']) {
    console.log(
      `  (aviso: profileImages['2'] = ${old['2']} pertenecía a la pestaña ` +
        `"Team" sintética — no se migra, no tiene dueño real.)`,
    );
  }
  return next;
}

// ── 4) Añadir winner_uid a game_history según winner_name ───────────────────
function addWinnerUid(docData) {
  const name = (docData.winner_name ?? docData.winnerName ?? '')
    .toString()
    .trim()
    .toLowerCase();

  let winnerUid = null;
  if (name === 'eme' || name === emeName.toLowerCase()) winnerUid = emeUid;
  else if (name === 'ceh' || name === cehName.toLowerCase()) winnerUid = cehUid;

  return winnerUid ? { ...docData, winner_uid: winnerUid } : docData;
}

// ── 5) Escribir en lotes de como máximo 400 operaciones ─────────────────────
async function commitInChunks(operations) {
  const CHUNK_SIZE = 400;
  for (let i = 0; i < operations.length; i += CHUNK_SIZE) {
    const batch = db.batch();
    for (const op of operations.slice(i, i + CHUNK_SIZE)) op(batch);
    await batch.commit();
    console.log(`  ✓ lote ${i / CHUNK_SIZE + 1} (${Math.min(CHUNK_SIZE, operations.length - i)} operaciones) escrito.`);
  }
}

// ── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  // Los uids reales solo existen si eme y ceh ya iniciaron sesión con el
  // build nuevo — sin sus documentos users/{uid} (y su groupIds), no hay
  // dónde añadir el grupo migrado.
  const [emeUserSnap, cehUserSnap] = await Promise.all([
    db.collection('users').doc(emeUid).get(),
    db.collection('users').doc(cehUid).get(),
  ]);
  if (!emeUserSnap.exists || !cehUserSnap.exists) {
    throw new Error(
      'eme y/o ceh todavía no tienen documento users/{uid} — deben iniciar ' +
        'sesión con Apple en el build nuevo al menos una vez antes de ' +
        'ejecutar esta migración.',
    );
  }

  const old = await readOldTree();

  const newGroupRef = db.collection('groups').doc(NEW_GROUP_ID);
  const profileImages = buildNewProfileImages(old.rootData);
  const players = buildNewPlayersMap(old.statsData);

  console.log('\n── Resumen ─────────────────────────────────────────────');
  console.log(`  Recuerdos a copiar:     ${old.memories.length}`);
  console.log(`  Ubicaciones a copiar:   ${old.locations.length}`);
  console.log(`  Partidas a copiar:      ${old.gameHistory.length}`);
  console.log(`  Jugadores en stats:     ${Object.keys(players).length} (${Object.keys(players).join(', ') || 'ninguno'})`);
  console.log(`  Fotos de perfil:        ${Object.keys(profileImages).length}`);
  console.log(`  groups/${NEW_GROUP_ID} → members: [${emeUid}, ${cehUid}]`);
  console.log('───────────────────────────────────────────────────────\n');

  if (!COMMIT) {
    console.log('Dry run completo. Repite con --commit cuando el resumen tenga sentido.');
    return;
  }

  const operations = [];

  operations.push((batch) =>
    batch.set(newGroupRef, {
      name: old.rootData.name ?? 'Nuestro hogar',
      isPersonal: false,
      members: [emeUid, cehUid],
      memberProfiles: {
        [emeUid]: { displayName: emeName, photoUrl: profileImages[emeUid] ?? null, joinedAt: FieldValue.serverTimestamp() },
        [cehUid]: { displayName: cehName, photoUrl: profileImages[cehUid] ?? null, joinedAt: FieldValue.serverTimestamp() },
      },
      profileImages,
      createdBy: emeUid,
      createdAt: old.rootData.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }),
  );

  for (const doc of old.memories) {
    operations.push((batch) => batch.set(newGroupRef.collection('memories').doc(doc.id), doc.data()));
  }
  for (const doc of old.locations) {
    operations.push((batch) => batch.set(newGroupRef.collection('locations').doc(doc.id), doc.data()));
  }
  for (const doc of old.gameHistory) {
    operations.push((batch) =>
      batch.set(newGroupRef.collection('game_history').doc(doc.id), addWinnerUid(doc.data())),
    );
  }
  if (Object.keys(players).length > 0) {
    operations.push((batch) =>
      batch.set(newGroupRef.collection('gamer_stats').doc('main_stats'), { players }),
    );
  }

  operations.push((batch) =>
    batch.update(db.collection('users').doc(emeUid), {
      groupIds: FieldValue.arrayUnion(NEW_GROUP_ID),
      updatedAt: FieldValue.serverTimestamp(),
    }),
  );
  operations.push((batch) =>
    batch.update(db.collection('users').doc(cehUid), {
      groupIds: FieldValue.arrayUnion(NEW_GROUP_ID),
      updatedAt: FieldValue.serverTimestamp(),
    }),
  );

  await commitInChunks(operations);

  console.log(
    `\n✅ Migración completa. users/${OLD_HOUSEHOLD_DOC_ID}/** no se ha tocado ` +
      '(queda como copia de seguridad). eme y ceh conservan también su ' +
      'grupo personal, además de este grupo migrado.',
  );
}

main().catch((err) => {
  console.error('\n❌', err.message);
  process.exit(1);
});
