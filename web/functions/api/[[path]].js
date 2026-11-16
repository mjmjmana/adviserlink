export async function onRequest({ request, env }) {
  const configuredOrigin = env.API_ORIGIN;
  if (!configuredOrigin) {
    return Response.json(
      { detail: "Account features are temporarily unavailable because the AdviserLink server is not configured yet." },
      { status: 503 },
    );
  }

  let apiOrigin;
  try {
    apiOrigin = new URL(configuredOrigin);
  } catch {
    return Response.json(
      { detail: "The AdviserLink server configuration is invalid. Please try again later." },
      { status: 500 },
    );
  }
  if (apiOrigin.protocol !== "https:" || apiOrigin.pathname !== "/" || apiOrigin.search || apiOrigin.hash) {
    return Response.json(
      { detail: "The AdviserLink server configuration is invalid. Please try again later." },
      { status: 500 },
    );
  }

  const targetUrl = new URL(request.url);
  targetUrl.protocol = apiOrigin.protocol;
  targetUrl.host = apiOrigin.host;

  const upstreamRequest = new Request(targetUrl, request);
  return fetch(upstreamRequest);
}
