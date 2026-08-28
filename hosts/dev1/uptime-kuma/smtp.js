const nodemailer = require("nodemailer");
const { escape } = require("html-escaper");

let NotificationProvider;
try {
    NotificationProvider = require("./notification-provider");
} catch (e) {
    try {
        NotificationProvider = require("/app/server/notification-providers/notification-provider");
    } catch (e2) {
        NotificationProvider = class {};
    }
}

let DOWN = 0, UP = 1, PENDING = 2, MAINTENANCE = 3, getMonitorRelativeURL = (id) => `/dashboard/${id}`;
try {
    const util = require("../../src/util");
    DOWN = util.DOWN !== undefined ? util.DOWN : 0;
    UP = util.UP !== undefined ? util.UP : 1;
    PENDING = util.PENDING !== undefined ? util.PENDING : 2;
    MAINTENANCE = util.MAINTENANCE !== undefined ? util.MAINTENANCE : 3;
    if (util.getMonitorRelativeURL) {
        getMonitorRelativeURL = util.getMonitorRelativeURL;
    }
} catch (e) {
    try {
        const util = require("/app/src/util");
        DOWN = util.DOWN !== undefined ? util.DOWN : 0;
        UP = util.UP !== undefined ? util.UP : 1;
        PENDING = util.PENDING !== undefined ? util.PENDING : 2;
        MAINTENANCE = util.MAINTENANCE !== undefined ? util.MAINTENANCE : 3;
        if (util.getMonitorRelativeURL) {
            getMonitorRelativeURL = util.getMonitorRelativeURL;
        }
    } catch (e2) {}
}

let setting;
try {
    setting = require("../util-server").setting;
} catch (e) {
    try {
        setting = require("/app/server/util-server").setting;
    } catch (e2) {
        setting = async () => null;
    }
}

/**
 * Enhanced SMTP Notification Provider for Uptime Kuma
 * Generates rich, modern, responsive HTML alert emails and structured text summaries.
 */
class SMTP extends NotificationProvider {

    name = "smtp";

    /**
     * Format duration in seconds to a human-readable string (e.g., "2m 15s")
     * @param {number} seconds 
     * @returns {string}
     */
    formatDuration(seconds) {
        if (!seconds || seconds <= 0) return "N/A";
        const d = Math.floor(seconds / 86400);
        const h = Math.floor((seconds % 86400) / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = Math.floor(seconds % 60);

        const parts = [];
        if (d > 0) parts.push(`${d}d`);
        if (h > 0) parts.push(`${h}h`);
        if (m > 0) parts.push(`${m}m`);
        if (s > 0 || parts.length === 0) parts.push(`${s}s`);
        return parts.join(" ");
    }

    /**
     * Convert monitor type string into a readable label
     * @param {string} type
     * @returns {string}
     */
    getMonitorTypeLabel(type) {
        const types = {
            "http": "HTTP(s) Endpoint",
            "port": "TCP Port / Service",
            "ping": "Ping (ICMP)",
            "keyword": "HTTP Keyword Search",
            "json-query": "JSON Query API",
            "docker": "Docker Container",
            "dns": "DNS Record Query",
            "push": "Push Heartbeat",
            "steam": "Steam Game Server",
            "gamedig": "Game Server (GameDig)",
            "mqtt": "MQTT Broker / Topic",
            "sqlserver": "Microsoft SQL Server",
            "postgres": "PostgreSQL Database",
            "mysql": "MySQL / MariaDB",
            "redis": "Redis Server",
            "mongodb": "MongoDB Database",
            "radius": "RADIUS Server",
            "grpc": "gRPC Service",
            "group": "Monitor Group",
            "real-browser": "Real Browser (Chromium)"
        };
        return types[type] || (type ? type.toUpperCase() : "Service");
    }

    /**
     * Main send implementation
     */
    async send(notification, msg, monitorJSON = null, heartbeatJSON = null) {
        const config = {
            host: notification.smtpHost,
            port: notification.smtpPort,
            secure: notification.smtpSecure,
            tls: {
                rejectUnauthorized: !notification.smtpIgnoreTLSError || false,
            }
        };

        if (notification.smtpDkimDomain) {
            config.dkim = {
                domainName: notification.smtpDkimDomain,
                keySelector: notification.smtpDkimKeySelector,
                privateKey: notification.smtpDkimPrivateKey,
                hashAlgo: notification.smtpDkimHashAlgo,
                headerFieldNames: notification.smtpDkimheaderFieldNames,
                skipFields: notification.smtpDkimskipFields,
            };
        }

        if (notification.smtpUsername || notification.smtpPassword) {
            config.auth = {
                user: notification.smtpUsername,
                pass: notification.smtpPassword,
            };
        }

        // Determine notification context
        const isTest = (heartbeatJSON == null && monitorJSON == null && (msg.endsWith("Testing") || msg.toLowerCase().includes("testing")));
        const isCert = (heartbeatJSON == null && msg.toLowerCase().includes("certificate") && msg.toLowerCase().includes("expired"));
        
        let statusType = "INFO";
        if (isTest) {
            statusType = "TEST";
        } else if (isCert) {
            statusType = "CERT_EXPIRY";
        } else if (heartbeatJSON) {
            if (heartbeatJSON.status === DOWN) {
                statusType = "DOWN";
            } else if (heartbeatJSON.status === UP) {
                statusType = "UP";
            } else if (heartbeatJSON.status === PENDING) {
                statusType = "PENDING";
            } else if (heartbeatJSON.status === MAINTENANCE) {
                statusType = "MAINTENANCE";
            }
        }

        // Resolve monitor target URL or host
        let targetAddress = "N/A";
        let targetLink = null;

        if (monitorJSON) {
            if (["http", "keyword", "json-query", "real-browser"].includes(monitorJSON.type) && monitorJSON.url) {
                targetAddress = monitorJSON.url;
                targetLink = monitorJSON.url;
            } else if (["port", "dns", "gamedig", "steam"].includes(monitorJSON.type)) {
                targetAddress = monitorJSON.hostname + (monitorJSON.port ? `:${monitorJSON.port}` : "");
            } else if (monitorJSON.type === "docker") {
                targetAddress = `Container: ${monitorJSON.docker_container || monitorJSON.name}`;
            } else if (monitorJSON.type === "ping") {
                targetAddress = monitorJSON.hostname || "ICMP Target";
            } else if (monitorJSON.type === "push") {
                targetAddress = "Push Heartbeat Token";
            } else {
                targetAddress = monitorJSON.url || monitorJSON.hostname || monitorJSON.name || "N/A";
            }
        } else if (isTest) {
            targetAddress = `${notification.smtpHost}:${notification.smtpPort}`;
        }

        // Determine monitor name
        const monitorName = monitorJSON ? monitorJSON.name : (isTest ? "Notification Test" : (isCert ? "SSL Certificate" : "Homelab Service"));

        // Format Subject
        let subject = msg;
        if (notification.customSubject && notification.customSubject.trim() !== "") {
            let customSubject = notification.customSubject.trim();
            let serviceStatus = "ℹ️ Alert";
            if (statusType === "DOWN") serviceStatus = "🔴 Down";
            else if (statusType === "UP") serviceStatus = "✅ Up";
            else if (statusType === "TEST") serviceStatus = "🧪 Test";
            else if (statusType === "CERT_EXPIRY") serviceStatus = "⚠️ Warning";
            else if (statusType === "MAINTENANCE") serviceStatus = "⏸️ Maintenance";

            customSubject = customSubject.replace(new RegExp("{{STATUS}}", "g"), serviceStatus);
            customSubject = customSubject.replace(new RegExp("{{NAME}}", "g"), monitorName);
            customSubject = customSubject.replace(new RegExp("{{HOSTNAME_OR_URL}}", "g"), targetAddress);
            customSubject = customSubject.replace(new RegExp("{{MESSAGE}}", "g"), msg);
            subject = customSubject;
        } else {
            if (statusType === "DOWN") {
                subject = `🔴 [DOWN] ${monitorName} (${targetAddress})`;
            } else if (statusType === "UP") {
                subject = `✅ [RESOLVED] ${monitorName} is UP (${targetAddress})`;
            } else if (statusType === "CERT_EXPIRY") {
                subject = `⚠️ [CERTIFICATE EXPIRING] ${monitorName}`;
            } else if (statusType === "TEST") {
                subject = `🧪 [TEST] Uptime Kuma Notification Channel: ${notification.name}`;
            } else if (statusType === "MAINTENANCE") {
                subject = `⏸️ [MAINTENANCE] ${monitorName}`;
            }
        }

        // Fetch Dashboard Base URL
        let baseURL = "";
        try {
            baseURL = await setting("primaryBaseURL");
        } catch (e) {
            baseURL = "";
        }
        if (!baseURL && process.env.UPTIME_KUMA_BASE_URL) {
            baseURL = process.env.UPTIME_KUMA_BASE_URL;
        }
        if (!baseURL) {
            baseURL = "https://dev1.<tailnet>.ts.net:3001";
        }
        if (baseURL.endsWith("/")) {
            baseURL = baseURL.slice(0, -1);
        }

        const monitorDashboardURL = monitorJSON ? `${baseURL}${getMonitorRelativeURL(monitorJSON.id)}` : `${baseURL}/dashboard`;

        // Extract and format heartbeat metrics
        const localTime = heartbeatJSON?.localDateTime || new Date().toISOString().replace("T", " ").substring(0, 19);
        const timezone = heartbeatJSON?.timezone || "UTC";
        const errorOrResponseMsg = heartbeatJSON?.msg || (isTest ? "SMTP configuration test successful. Alert messages will be delivered to this inbox." : msg);
        const pingValue = heartbeatJSON?.ping != null ? `${heartbeatJSON.ping} ms` : null;
        const durationText = heartbeatJSON?.duration ? this.formatDuration(heartbeatJSON.duration) : null;
        const monitorTypeLabel = monitorJSON ? this.getMonitorTypeLabel(monitorJSON.type) : "System Alert";
        const tags = (monitorJSON && Array.isArray(monitorJSON.tags)) ? monitorJSON.tags : [];

        // Build status visual config
        const statusConfigs = {
            "DOWN": {
                themeColor: "#dc2626",
                themeGradient: "linear-gradient(135deg, #dc2626 0%, #991b1b 100%)",
                badgeBg: "#fee2e2",
                badgeBorder: "#f87171",
                badgeText: "#991b1b",
                badgeLabel: "🔴 CRITICAL / DOWN",
                headline: "Service Incident Detected",
                headlineSubtitle: `The service <strong>${escape(monitorName)}</strong> is currently down or failing health checks.`,
                boxBg: "#fef2f2",
                boxBorder: "#ef4444",
                boxText: "#991b1b",
                boxTitle: "INCIDENT / ERROR DETAILS"
            },
            "UP": {
                themeColor: "#16a34a",
                themeGradient: "linear-gradient(135deg, #16a34a 0%, #15803d 100%)",
                badgeBg: "#dcfce7",
                badgeBorder: "#86efac",
                badgeText: "#166534",
                badgeLabel: "✅ OPERATIONAL / UP",
                headline: "Service Recovered & Operational",
                headlineSubtitle: `The service <strong>${escape(monitorName)}</strong> has recovered and is responding normally.`,
                boxBg: "#f0fdf4",
                boxBorder: "#22c55e",
                boxText: "#166534",
                boxTitle: "HEALTHCHECK VERIFICATION"
            },
            "CERT_EXPIRY": {
                themeColor: "#d97706",
                themeGradient: "linear-gradient(135deg, #d97706 0%, #b45309 100%)",
                badgeBg: "#fef3c7",
                badgeBorder: "#fcd34d",
                badgeText: "#92400e",
                badgeLabel: "⚠️ CERTIFICATE EXPIRY",
                headline: "SSL/TLS Certificate Notice",
                headlineSubtitle: `An SSL/TLS certificate for <strong>${escape(monitorName)}</strong> is nearing expiration.`,
                boxBg: "#fffbeb",
                boxBorder: "#f59e0b",
                boxText: "#92400e",
                boxTitle: "EXPIRATION DETAILS"
            },
            "TEST": {
                themeColor: "#4f46e5",
                themeGradient: "linear-gradient(135deg, #4f46e5 0%, #3730a3 100%)",
                badgeBg: "#e0e7ff",
                badgeBorder: "#a5b4fc",
                badgeText: "#3730a3",
                badgeLabel: "🧪 NOTIFICATION TEST",
                headline: "Email Notification Test",
                headlineSubtitle: `Brevo SMTP integration is functioning properly for <strong>${escape(notification.name || "Uptime Kuma")}</strong>.`,
                boxBg: "#f8fafc",
                boxBorder: "#6366f1",
                boxText: "#334155",
                boxTitle: "INTEGRATION STATUS"
            },
            "MAINTENANCE": {
                themeColor: "#0284c7",
                themeGradient: "linear-gradient(135deg, #0284c7 0%, #0369a1 100%)",
                badgeBg: "#e0f2fe",
                badgeBorder: "#7dd3fc",
                badgeText: "#075985",
                badgeLabel: "⏸️ MAINTENANCE",
                headline: "Scheduled Maintenance Active",
                headlineSubtitle: `The service <strong>${escape(monitorName)}</strong> is currently under planned maintenance.`,
                boxBg: "#f0f9ff",
                boxBorder: "#0ea5e9",
                boxText: "#075985",
                boxTitle: "MAINTENANCE INFO"
            },
            "INFO": {
                themeColor: "#475569",
                themeGradient: "linear-gradient(135deg, #475569 0%, #334155 100%)",
                badgeBg: "#f1f5f9",
                badgeBorder: "#cbd5e1",
                badgeText: "#334155",
                badgeLabel: "ℹ️ SYSTEM NOTICE",
                headline: "Monitoring System Notice",
                headlineSubtitle: `Notice for <strong>${escape(monitorName)}</strong>.`,
                boxBg: "#f8fafc",
                boxBorder: "#64748b",
                boxText: "#334155",
                boxTitle: "NOTICE DETAILS"
            }
        };

        const currentStyle = statusConfigs[statusType] || statusConfigs["INFO"];

        // Format tags HTML
        let tagsHtml = "";
        if (tags.length > 0) {
            tagsHtml = tags.map(t => {
                const bg = t.color || "#64748b";
                return `<span style="display:inline-block; background-color:${escape(bg)}; color:#ffffff; font-size:11px; font-weight:600; padding:2px 8px; border-radius:12px; margin-right:4px;">${escape(t.name)}</span>`;
            }).join(" ");
        }

        // Generate Responsive HTML Email
        const htmlBody = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark">
  <title>${escape(subject)}</title>
</head>
<body style="margin:0; padding:0; background-color:#f1f5f9; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; -webkit-font-smoothing:antialiased; color:#1e293b;">
  <table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color:#f1f5f9; padding:24px 12px;">
    <tr>
      <td align="center">
        <!-- Container Card -->
        <table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width:620px; background-color:#ffffff; border-radius:12px; overflow:hidden; box-shadow:0 4px 16px rgba(0,0,0,0.06); border:1px solid #e2e8f0;">
          
          <!-- Top Accent Header Banner -->
          <tr>
            <td style="background:${currentStyle.themeGradient}; padding:20px 28px; text-align:left;">
              <table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0">
                <tr>
                  <td>
                    <div style="display:inline-block; font-size:11px; font-weight:700; color:#ffffff; text-transform:uppercase; letter-spacing:1px; opacity:0.9;">
                      Homelab dev1 • Uptime Kuma
                    </div>
                    <div style="font-size:20px; font-weight:800; color:#ffffff; margin-top:4px;">
                      ${escape(currentStyle.headline)}
                    </div>
                  </td>
                  <td align="right" valign="middle">
                    <span style="display:inline-block; background:rgba(255,255,255,0.2); backdrop-filter:blur(4px); color:#ffffff; font-size:12px; font-weight:700; padding:6px 14px; border-radius:20px; border:1px solid rgba(255,255,255,0.3); text-transform:uppercase; letter-spacing:0.5px;">
                      ${escape(currentStyle.badgeLabel)}
                    </span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main Content Body -->
          <tr>
            <td style="padding:28px 28px 20px 28px;">
              
              <!-- Subtitle / Intro -->
              <p style="margin:0 0 20px 0; font-size:15px; line-height:1.6; color:#475569;">
                ${currentStyle.headlineSubtitle}
              </p>

              <!-- Highlighted Output Box -->
              <table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" style="margin-bottom:24px; background-color:${currentStyle.boxBg}; border:1px solid #e2e8f0; border-left:4px solid ${currentStyle.boxBorder}; border-radius:8px;">
                <tr>
                  <td style="padding:14px 18px;">
                    <div style="font-size:11px; font-weight:800; color:${currentStyle.boxText}; text-transform:uppercase; letter-spacing:0.8px; margin-bottom:6px;">
                      ${escape(currentStyle.boxTitle)}
                    </div>
                    <div style="font-family:ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace; font-size:13px; color:#1e293b; line-height:1.5; word-break:break-word;">
                      ${escape(errorOrResponseMsg)}
                    </div>
                  </td>
                </tr>
              </table>

              <!-- Detailed Metrics & Information Table -->
              <table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; margin-bottom:24px; font-size:13px; border-collapse:collapse;">
                <tr style="border-bottom:1px solid #e2e8f0;">
                  <td style="padding:12px 16px; font-weight:600; color:#64748b; width:34%;">Service Name</td>
                  <td style="padding:12px 16px; font-weight:700; color:#0f172a;">${escape(monitorName)}</td>
                </tr>
                <tr style="border-bottom:1px solid #e2e8f0;">
                  <td style="padding:12px 16px; font-weight:600; color:#64748b;">Target / Endpoint</td>
                  <td style="padding:12px 16px; color:#0f172a; word-break:break-all;">
                    ${targetLink ? `<a href="${escape(targetLink)}" target="_blank" style="color:#2563eb; text-decoration:none; font-weight:500;">${escape(targetAddress)} ↗</a>` : escape(targetAddress)}
                  </td>
                </tr>
                <tr style="border-bottom:1px solid #e2e8f0;">
                  <td style="padding:12px 16px; font-weight:600; color:#64748b;">Monitor Type</td>
                  <td style="padding:12px 16px; color:#334155; font-weight:500;">${escape(monitorTypeLabel)}</td>
                </tr>
                ${pingValue ? `
                <tr style="border-bottom:1px solid #e2e8f0;">
                  <td style="padding:12px 16px; font-weight:600; color:#64748b;">Response Latency</td>
                  <td style="padding:12px 16px; color:#0f172a; font-weight:600;">⚡ ${escape(pingValue)}</td>
                </tr>` : ''}
                ${durationText ? `
                <tr style="border-bottom:1px solid #e2e8f0;">
                  <td style="padding:12px 16px; font-weight:600; color:#64748b;">State Duration</td>
                  <td style="padding:12px 16px; color:#0f172a; font-weight:600;">⏱️ ${escape(durationText)}</td>
                </tr>` : ''}
                <tr style="border-bottom:1px solid #e2e8f0;">
                  <td style="padding:12px 16px; font-weight:600; color:#64748b;">Timestamp</td>
                  <td style="padding:12px 16px; color:#334155;">${escape(localTime)} (${escape(timezone)})</td>
                </tr>
                ${tagsHtml ? `
                <tr style="border-bottom:1px solid #e2e8f0;">
                  <td style="padding:12px 16px; font-weight:600; color:#64748b;">Tags</td>
                  <td style="padding:12px 16px;">${tagsHtml}</td>
                </tr>` : ''}
                ${(monitorJSON && monitorJSON.description) ? `
                <tr>
                  <td style="padding:12px 16px; font-weight:600; color:#64748b;">Description</td>
                  <td style="padding:12px 16px; color:#475569;">${escape(monitorJSON.description)}</td>
                </tr>` : ''}
              </table>

              <!-- Call to Action Buttons -->
              <table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" style="margin-bottom:8px;">
                <tr>
                  <td align="left">
                    <a href="${escape(monitorDashboardURL)}" target="_blank" style="display:inline-block; background-color:#0f172a; color:#ffffff; font-size:13px; font-weight:600; text-decoration:none; padding:10px 20px; border-radius:6px; margin-right:10px; margin-bottom:8px;">
                      View in Uptime Kuma →
                    </a>
                    ${targetLink ? `
                    <a href="${escape(targetLink)}" target="_blank" style="display:inline-block; background-color:#ffffff; color:#334155; font-size:13px; font-weight:600; text-decoration:none; padding:10px 18px; border-radius:6px; border:1px solid #cbd5e1; margin-bottom:8px;">
                      Open Service ↗
                    </a>` : ''}
                  </td>
                </tr>
              </table>

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color:#f8fafc; border-top:1px solid #e2e8f0; padding:16px 28px; text-align:center;">
              <div style="font-size:12px; color:#64748b; font-weight:500;">
                Sent automatically by <strong>Uptime Kuma</strong> • Homelab Infrastructure Monitoring
              </div>
              <div style="font-size:11px; color:#94a3b8; margin-top:4px;">
                Channel: ${escape(notification.name || 'SMTP')} • ${escape(new Date().toUTCString())}
              </div>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

        // Generate Clean Fallback Plain-Text
        const textLines = [
            "============================================================",
            ` ${currentStyle.badgeLabel}: ${monitorName}`,
            "============================================================",
            `Service Name : ${monitorName}`,
            `Status       : ${currentStyle.badgeLabel}`,
            `Target       : ${targetAddress}`,
            `Monitor Type : ${monitorTypeLabel}`,
            pingValue ? `Latency      : ${pingValue}` : null,
            durationText ? `Duration     : ${durationText}` : null,
            `Timestamp    : ${localTime} (${timezone})`,
            "------------------------------------------------------------",
            `Details/Error: ${errorOrResponseMsg}`,
            "------------------------------------------------------------",
            `Dashboard    : ${monitorDashboardURL}`,
            targetLink ? `Service Link : ${targetLink}` : null,
            "============================================================",
            "Sent by Uptime Kuma (Homelab dev1)"
        ].filter(line => line !== null).join("\n");

        // Send Email
        const transporter = nodemailer.createTransport(config);

        await transporter.sendMail({
            from: notification.smtpFrom,
            cc: notification.smtpCC,
            bcc: notification.smtpBCC,
            to: notification.smtpTo,
            subject: subject,
            text: textLines,
            html: htmlBody,
        });

        return "Sent Successfully.";
    }
}

module.exports = SMTP;
