/// The YouTube page that plays [videoId], for when the app can't play it.
Uri youtubeWatchUrl(String videoId) =>
    Uri.https('www.youtube.com', '/watch', {'v': videoId});
