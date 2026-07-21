export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const cache = caches.default;

    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    const comboMatch = url.pathname.match(/^\/v4\/combo\/anime\/(\d+)$/);
    if (comboMatch) {
      return handleCombo(request, url, env, ctx, cache, comboMatch[1]);
    }

    return handlePassthrough(request, url, env, ctx, cache);
  },
};

async function handleCombo(request, url, env, ctx, cache, tvdbId) {
  let response = await cache.match(request);
  if (response) {
    console.log("Combo Cache Hit");
    return response;
  }

  console.log(`Combo Cache Miss → TVDB ID ${tvdbId}`);

  const lang = url.searchParams.get("lang") || "spa";
  const headers = {
    Authorization: `Bearer ${env.TVDB_API_TOKEN}`,
    Accept: "application/json",
    "User-Agent": "Aniting-App-Proxy/1.0",
  };

  const episodesUrl = `https://api4.thetvdb.com/v4/series/${tvdbId}/episodes/official/${lang}?page=0`;
  const seriesUrl = `https://api4.thetvdb.com/v4/series/${tvdbId}/extended?meta=translations`;  

  const [episodesRes, seriesRes] = await Promise.allSettled([
    fetch(new Request(episodesUrl, { headers, method: "GET" })),
    fetch(new Request(seriesUrl, { headers, method: "GET" })),
  ]);

  let allEpisodes = [];
  if (episodesRes.status === "fulfilled" && episodesRes.value.ok) {
    const epJson = await episodesRes.value.json();
    allEpisodes = (epJson?.data?.episodes || []).filter(ep => ep && ep.number);
  }

  // Group episodes by season
  const episodesBySeason = {};
  for (const ep of allEpisodes) {
    const sn = ep.seasonNumber ?? 0;
    if (!episodesBySeason[sn]) episodesBySeason[sn] = [];
    episodesBySeason[sn].push({
      id: ep.id,
      number: ep.number,
      name: ep.name || `Episodio ${ep.number}`,
      overview: ep.overview || null,
      image: ep.image || null,
      aired: ep.aired || null,
      runtime: ep.runtime || null,
      seasonNumber: sn,
    });
  }
  let seasons = [];

  let details = null;
  let isMovie = false;
  if (seriesRes.status === "fulfilled" && seriesRes.value.ok) {
    const json = await seriesRes.value.json();
    details = json?.data || null;
  }

  if (!details) {
    try {
      const movieUrl = `https://api4.thetvdb.com/v4/movies/${tvdbId}/extended?meta=translations`;
      const movieRes = await fetch(new Request(movieUrl, { headers, method: "GET" }));
      if (movieRes.ok) {
        const json = await movieRes.json();
        details = json?.data || null;
        isMovie = true;
        // Populate a pseudo-episode for the movie so clients see a single episode
        const movieEp = {
          id: details.id || tvdbId,
          number: 1,
          name: details.name || details.title || "Película",
          overview: details.overview || null,
          image: details.artwork || null,
          aired: details.releaseDate || details.premiereDate || null,
          runtime: details.runtime || null,
          seasonNumber: 0,
        };
        episodesBySeason[0] = [movieEp];
      }
    } catch (_) {}
  }

  // Rebuild seasons list sorted (after possible movie population)
  const seasonKeys = Object.keys(episodesBySeason)
    .map(Number)
    .sort((a, b) => a - b);

  seasons = seasonKeys.map(sn => ({
    seasonNumber: sn,
    episodeCount: episodesBySeason[sn].length,
    firstEpisode: episodesBySeason[sn][0]?.number,
    lastEpisode: episodesBySeason[sn][episodesBySeason[sn].length - 1]?.number,
  }));

  let logo = null, banner = null, poster = null;
  let localizedName = null, localizedOverview = null;

  if (details) {
    localizedName = details.name || null;
    localizedOverview = details.overview || null;

    const translations = details.translations;
    if (Array.isArray(translations)) {
      for (const t of translations) {
        if (t?.language === "spa" || t?.language === "es") {
          if (t.overview) localizedOverview = t.overview;
          if (t.name) localizedName = t.name;
          break;
        }
      }
    }

    const artworks = details.artworks;
    if (Array.isArray(artworks)) {
      const logoByLang = {};
      for (const art of artworks) {
        if (!art?.image) continue;
        if (art.type === 23) {
          logoByLang[art.language || "und"] = art.image;
        } else if (art.type === 7 && !poster) {
          poster = art.image;
        } else if ((art.type === 2 || art.type === 1) && !banner) {
          banner = art.image;
        }
      }
      logo = logoByLang["spa"] || logoByLang["es"] || logoByLang["eng"] ||
             logoByLang["jpn"] || Object.values(logoByLang)[0] || null;
    }
  }

  const combo = {
    data: {
      episodesBySeason,
      seasons,
      logo,
      banner,
      poster,
      overview: localizedOverview,
      name: localizedName,
    },
  };

  response = new Response(JSON.stringify(combo), {
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "s-maxage=86400",
      "Access-Control-Allow-Origin": "*",
    },
  });

  ctx.waitUntil(cache.put(request, response.clone()));
  return response;
}

async function handlePassthrough(request, url, env, ctx, cache) {
  const targetUrl = "https://api4.thetvdb.com" + url.pathname + url.search;
  let response = await cache.match(request);
  if (response) return response;

  const newRequest = new Request(targetUrl, {
    headers: {
      Authorization: `Bearer ${env.TVDB_API_TOKEN}`,
      Accept: "application/json",
      "User-Agent": "Aniting-App-Proxy/1.0",
    },
    method: request.method,
  });

  response = await fetch(newRequest);
  if (response.status === 200) {
    response = new Response(response.body, response);
    response.headers.set("Cache-Control", "s-maxage=86400");
    ctx.waitUntil(cache.put(request, response.clone()));
  }
  return response;
}