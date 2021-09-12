import { getAssetFromKV, NotFoundError } from '@cloudflare/kv-asset-handler';
import acceptLanguageParser from 'accept-language-parser';

/**
 * The DEBUG flag will do two things that help during development:
 * 1. we will skip caching on the edge, which makes it easier to
 *    debug.
 * 2. we will return an error message on exception in your Response rather
 *    than the default 404.html page.
 */
const DEBUG = false

const SUPPORTED_LANGUAGES = ['en', 'pt'];

addEventListener('fetch', event => {
  try {
    event.respondWith(handleEvent(event))
  } catch (e) {
    console.error("Failed to respond", e);

    if (DEBUG) {
      return event.respondWith(
        new Response(e.message || e.toString(), {
          status: 500,
        }),
      )
    }

    event.respondWith(new Response('Internal Error', { status: 500 }))
  }
})

async function handleEvent(event) {
  try {
    const options = {};

    if (DEBUG) {
      // customize caching
      options.cacheControl = {
        bypassCache: true,
      }
    }

    const parsedURL = new URL(event.request.url);
    if (parsedURL.pathname === '/') {
      const lang = getPreferredLanguage(event.request);
      return Response.redirect(`${parsedURL.origin}/${lang}/`, 303);
    }

    const page = await getAssetFromKV(event, options);

    // allow headers to be altered
    const response = new Response(page.body, page);

    if (event.request.url.endsWith('/feed.xml')) {
      response.headers.set('Content-Type', 'application/rss+xml');
    }
    response.headers.set('Content-Security-Policy', "script-src 'self'");
    response.headers.set('X-XSS-Protection', '1; mode=block');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('X-Frame-Options', 'DENY');
    response.headers.set('Referrer-Policy', 'unsafe-url');
    response.headers.set('Feature-Policy', 'none');

    return response
  } catch (e) {
    // if an error is thrown try to serve the asset at 404.html
    if (DEBUG) {
      console.error("Error fetching resource", e);
      return new Response(e.message || e.toString(), { status: 500 })
    }

    let errStatus;
    if (e instanceof NotFoundError) {
      errStatus = 404;
    } else {
      console.error("Error building response", e);
      errStatus = 500;
    }

    function getLanguageFromURLOrPreferred(req, parsedURL) {
      if (parsedURL.pathname.length <= 3 || parsedURL.pathname[3] === '/') {
        if (parsedURL.pathname.startsWith('/en')) {
          return 'en';
        } else if (parsedURL.pathname.startsWith('/pt')) {
          return 'pt';
        }
      }
      return getPreferredLanguage(req);
    }

    function mapToError(req) {
      const parsedURL = new URL(req.url);
      const lang = getLanguageFromURLOrPreferred(req, parsedURL);
      return new Request(`${parsedURL.origin}/${lang}/${errStatus}.html`, req);
    }

    try {
      const errorPage = await getAssetFromKV(event, { mapRequestToAsset: mapToError });
      return new Response(errorPage.body, { ...errorPage, status: errStatus })
    } catch (e) {
      console.error(`Failed to find error page ${errStatus}`, e);
    }
  }
}

function getPreferredLanguage(request) {
  const acceptLanguage = request.headers.get('Accept-Language') || '';
  const lang = acceptLanguageParser.pick(SUPPORTED_LANGUAGES, acceptLanguage, { loose: true });
  if (lang !== null) {
    return lang;
  }
  if ((request.cf || {}).country == 'BR') {
    return 'pt';
  }
  return 'en';
}
