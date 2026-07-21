const fetch = require('node-fetch');
const fs = require('fs');

// Lista de IDs de la Temporada 1 de franquicias multi-temporada
const ANCHOR_IDS = [
    // --- LOS IMPRESCINDIBLES (Shonen & Acción) ---
    101922, // Demon Slayer
    113415, // Jujutsu Kaisen
    16498,  // Attack on Titan
    21459,  // My Hero Academia
    21085,  // One Punch Man
    105333, // Dr. Stone
    20464,  // Haikyuu!!
    151807, // Solo Leveling

    // --- ISEKAI & FANTASÍA (Mucha tela que cortar) ---
    108465, // Mushoku Tensei
    21355,  // Re:Zero
    101280, // Tensura (Slime)
    21202,  // KonoSuba
    11757,  // Sword Art Online
    108511, // Shield Hero
    133007, // The Eminence in Shadow
    154587, // Frieren
    100166, // Overlord
    101759, // DanMachi

    // --- ROMANCE & DRAMA (Con secuelas o películas) ---
    14813,  // Oregairu
    101291, // Bunny Girl Senpai
    103974, // Kaguya-sama
    150672, // Oshi no Ko
    9989,   // Anohana (Serie + Película)
    116589, // 86: Eighty Six
    101921, // Kaguya-sama
    125367, // Rent-a-Girlfriend
    117170, // Horimiya (Temporada + Piece)

    // --- CLÁSICOS Y LARGOS ---
    269,    // Bleach
    20785,  // The Seven Deadly Sins
    5081,   // Bakemonogatari (Saga Monogatari)
    6702,   // Fairy Tail
    1575,   // Code Geass
    9253,   // Steins;Gate

    // --- SEINEN & OTROS ---
    101348, // Vinland Saga
    21507,  // Mob Psycho 100
    137822, // Blue Lock
    140960, // Spy x Family
    110277, // Shingeki no Kyojin: The Final Season
    110652, // Beastars
    101759, // Is It Wrong to Try to Pick Up Girls in a Dungeon?
    151047  // Haikyuu!! Movie: Battle at the Garbage Dump
];

const url = 'https://graphql.anilist.co';

async function getAnimeRelations(id, visited = new Set()) {
    if (visited.has(id)) return [];
    visited.add(id);

    const query = `
    query ($id: Int) {
      Media (id: $id, type: ANIME) {
        id
        title { romaji english }
        format
        episodes
        relations {
          edges {
            relationType
            node {
              id
              title { romaji english }
              format
            }
          }
        }
      }
    }`;

    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
            body: JSON.stringify({ query, variables: { id } })
        });
        const data = await response.json();
        if (!data.data.Media) return [];

        let current = data.data.Media;
        let results = [{
            id: current.id,
            label: current.title.romaji,
            format: current.format,
            episodes: current.episodes
        }];

        // Pausa para respetar el rate limit
        await new Promise(resolve => setTimeout(resolve, 700));

        for (const edge of current.relations.edges) {
            const rel = edge.relationType;
            // Solo seguimos secuelas, precuelas y parent para no irnos por las ramas infinitas
            if (['SEQUEL', 'PREQUEL', 'PARENT'].includes(rel)) {
                const subResults = await getAnimeRelations(edge.node.id, visited);
                results = [...results, ...subResults];
            }
        }
        return results;
    } catch (err) {
        console.error(`Error en ID ${id}:`, err);
        return [];
    }
}

async function start() {
    const fullMap = [];
    for (const anchor of ANCHOR_IDS) {
        console.log(`Mapeando franquicia de ID: ${anchor}...`);
        const relations = await getAnimeRelations(anchor);
        fullMap.push({
            anchorId: anchor,
            items: relations
        });
    }
    fs.writeFileSync('raw_mappings.json', JSON.stringify(fullMap, null, 2));
    console.log('¡Listo! Revisa raw_mappings.json');
}

start();