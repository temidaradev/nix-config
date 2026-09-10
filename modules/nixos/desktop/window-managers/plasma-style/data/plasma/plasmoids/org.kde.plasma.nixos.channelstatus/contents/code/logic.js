const state = {
  channelStatus: {
    lastUpdated: "Warte auf Verbindung...",
    revision: "",
    status: "waiting",
    channel: ""
  },
  retryCount: 0,
  maxRetries: 5,
  retryDelay: 5000,
  translateFunc: null,
  retryTimer: null,
  lastRetryAction: null
};

function fetchAPI(url) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.timeout = 10000;
    xhr.onerror = () => reject(new Error(tr("Keine Verbindung", "No connection")));
    xhr.ontimeout = () => reject(new Error("Timeout"));
    xhr.onreadystatechange = () => {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        if (xhr.status === 200) {
          try {
            const json = JSON.parse(xhr.responseText);
            resolve({status: "success", data: json});
          } catch (e) {
            reject(new Error("JSON Parse Error"));
          }
        } else {
          reject(new Error(tr("Keine Verbindung", "No connection")));
        }
      }
    };

    try {
      xhr.open("GET", url);
      xhr.send();
    } catch (e) {
      reject(new Error(e.toString()));
    }
  });
}

function fetchChannelStatus(version, callback, isRetry) {
  if (isRetry === undefined) isRetry = false;
  if (!isRetry) {
    state.retryCount = 0;
    if (state.retryTimer) state.retryTimer.stop();
    console.log("=== Lade Channel-Daten (Promise) ===");
  }

  const channelName = "nixos-" + version;
  const updateUrl = "https://prometheus.nixos.org/api/v1/query?query=channel_update_time";
  const revisionUrl = "https://prometheus.nixos.org/api/v1/query?query=channel_revision";

  const updatePromise = fetchAPI(updateUrl);
  const revisionPromise = fetchAPI(revisionUrl).catch(err => ({status: "error", error: err}));

  Promise.all([updatePromise, revisionPromise])
    .then(results => {
      const updateResult = results[0];
      const revisionResult = results[1];

      state.retryCount = 0;
      const channelData = findChannelInResponse(updateResult.data, channelName);

      if (channelData) {
        const revision = (revisionResult.status === "success")
          ? findRevisionForChannel(revisionResult.data, channelName)
          : {commit: "", fullCommit: ""};

        const status = {
          lastUpdated: formatDateTime(channelData.date),
          rawDateTime: channelData.date.toISOString(),
          timestamp: channelData.timestamp,
          commit: revision.commit,
          fullCommit: revision.fullCommit,
          status: "success",
          channel: channelName
        };

        state.channelStatus = status;
        callback(status);
      } else {
        const notFoundStatus = {
          lastUpdated: tr("Channel nicht gefunden", "Channel not found"),
          status: "not_found",
          channel: channelName
        };
        state.channelStatus = notFoundStatus;
        callback(notFoundStatus);
      }
    })
    .catch(error => {
      if (state.retryCount < state.maxRetries) {
        state.retryCount++;
        console.log(`⏳ Retry ${state.retryCount}/${state.maxRetries} (${error.message})`);

        const retryStatus = {
          lastUpdated: tr("Verbindungsfehler, Retry %1/%2...", "Connection error, retry %1/%2...", state.retryCount, state.maxRetries),
          status: "retrying",
          channel: channelName,
          retryCount: state.retryCount,
          maxRetries: state.maxRetries
        };

        state.channelStatus = retryStatus;
        callback(retryStatus);

        if (state.retryTimer) {
          state.lastRetryAction = () => fetchChannelStatus(version, callback, true);
          state.retryTimer.interval = state.retryDelay;
          state.retryTimer.start();
        } else {
          console.warn("No Retry Timer configured!");
        }
      } else {
        const errorStatus = {
          lastUpdated: tr("Keine Verbindung", "No connection"),
          status: "error",
          channel: channelName,
          error: error.message
        };
        state.retryCount = 0;
        state.channelStatus = errorStatus;
        callback(errorStatus);
      }
    });
}

function fetchAllChannels(callback) {
  console.log("=== Lade alle Channels (Promise) ===");
  const updateUrl = "https://prometheus.nixos.org/api/v1/query?query=channel_update_time";
  const revisionUrl = "https://prometheus.nixos.org/api/v1/query?query=channel_revision";

  Promise.all([
    fetchAPI(updateUrl).catch(e => ({status: "error"})),
    fetchAPI(revisionUrl).catch(e => ({status: "error"}))
  ]).then(results => {
    const updateResult = results[0];
    const revisionResult = results[1];

    if (updateResult.status !== "success") {
      callback([]);
      return;
    }

    const channels = parseAllChannels(updateResult.data,
      revisionResult.status === "success" ? revisionResult.data : null);
    callback(channels);

  }).catch(e => {
    console.error("Error fetching all channels:", e);
    callback([]);
  });
}

function findChannelInResponse(response, channelName) {
  if (!response?.data?.result) return null;

  for (const item of response.data.result) {
    if (item.metric.channel === channelName) {
      const timestamp = parseFloat(item.value[1]);
      return {
        channel: channelName,
        timestamp: timestamp,
        date: new Date(timestamp * 1000)
      };
    }
  }
  return null;
}

function findRevisionForChannel(response, channelName) {
  if (!response?.data?.result) return {commit: "", fullCommit: ""};

  for (const item of response.data.result) {
    if (item.metric.channel === channelName) {
      const revision = item.metric.revision || "";
      return {
        commit: revision.substring(0, 7),
        fullCommit: revision
      };
    }
  }
  return {commit: "", fullCommit: ""};
}

function parseAllChannels(updateData, revisionData) {
  if (!updateData?.data?.result) return [];

  const revisionMap = {};
  if (revisionData?.data?.result) {
    revisionData.data.result.forEach(item => {
      const revision = item.metric.revision || "";
      revisionMap[item.metric.channel] = {
        commit: revision.substring(0, 7),
        fullCommit: revision
      };
    });
  }

  const channels = updateData.data.result.map(item => {
    const channelName = item.metric.channel;
    const timestamp = parseFloat(item.value[1]);
    const date = new Date(timestamp * 1000);
    const revision = revisionMap[channelName] || {commit: "", fullCommit: ""};

    return {
      channel: channelName,
      lastUpdated: formatDateTime(date),
      rawDateTime: date.toISOString(),
      timestamp: timestamp,
      commit: revision.commit,
      fullCommit: revision.fullCommit
    };
  });

  channels.sort((a, b) => a.channel.localeCompare(b.channel));

  console.log("✓", channels.length, "Channels geladen");
  return channels;
}

function formatDateTime(date) {
  const now = new Date();
  const diffMs = now - date;
  const diffMinutes = Math.floor(diffMs / (1000 * 60));
  const diffHours = Math.floor(diffMinutes / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffMinutes < 1) return tr("gerade eben", "just now");
  if (diffMinutes < 60) {
    return tr("vor %1 Minute", "vor %1 Minuten", "%1 minute ago", "%1 minutes ago", diffMinutes);
  }
  if (diffHours < 24) {
    return tr("vor %1 Stunde", "vor %1 Stunden", "%1 hour ago", "%1 hours ago", diffHours);
  }
  if (diffDays < 30) {
    return tr("vor %1 Tag", "vor %1 Tagen", "%1 day ago", "%1 days ago", diffDays);
  }
  return Qt.formatDate(date, "dd.MM.yyyy");
}

function setTranslateFunction(trFunc) {
  state.translateFunc = trFunc;
}

function setRetryTimer(timer) {
  state.retryTimer = timer;
  state.retryTimer.triggered.connect(() => {
    console.log("⏰ Retry Timer triggered");
    if (state.lastRetryAction) {
      state.lastRetryAction();
    }
  });
}

function tr(...args) {
  if (!state.translateFunc) {
    // Basic fallback extraction (very rough)
    // tr(de, en) -> en
    // tr(deS, deP, enS, enP, count) -> count==1 ? enS : enP

    if (args.length === 2) return args[1];
    if (args.length >= 5) {
      const count = args[4];
      const enSingular = args[2];
      const enPlural = args[3];
      return (count === 1 ? enSingular : enPlural).replace("%1", count);
    }
    return args[args.length - 1] || "";
  }
  return state.translateFunc(...args);
}
