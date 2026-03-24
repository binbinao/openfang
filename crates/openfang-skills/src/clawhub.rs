//! ClawHub marketplace client — search and install skills from skillhub.tencent.com.
//!
//! ClawHub hosts 3,000+ community skills in both SKILL.md (prompt-only)
//! and package.json (Node.js) formats. This client downloads, converts,
//! and security-scans skills before installation.
//!
//! API backend: <https://lightmake.site/api/>
//! - Browse: `GET /api/skills?limit=20&sort=trending`
//! - Top: `GET /api/skills/top`
//! - Download: `GET /api/v1/download?slug=...`

use crate::openclaw_compat;
use crate::verify::{SkillVerifier, SkillWarning, WarningSeverity};
use crate::SkillError;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};
use tracing::{info, warn};

// ---------------------------------------------------------------------------
// API response types (matching lightmake.site API — verified Mar 2026)
// ---------------------------------------------------------------------------

// -- Shared nested types ---------------------------------------------------

/// Stats synthesized from the flat skill fields for backward compatibility.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClawHubStats {
    #[serde(default)]
    pub comments: u64,
    #[serde(default)]
    pub downloads: u64,
    #[serde(default)]
    pub installs_all_time: u64,
    #[serde(default)]
    pub installs_current: u64,
    #[serde(default)]
    pub stars: u64,
    #[serde(default)]
    pub versions: u64,
}

/// Version info nested inside browse entries and skill detail.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClawHubVersionInfo {
    #[serde(default)]
    pub version: String,
    #[serde(default)]
    pub created_at: i64,
    #[serde(default)]
    pub changelog: String,
}

/// Owner info from the skill detail endpoint.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClawHubOwner {
    #[serde(default)]
    pub handle: String,
    #[serde(default)]
    pub user_id: String,
    #[serde(default)]
    pub display_name: String,
    #[serde(default)]
    pub image: String,
}

// -- Raw API response wrappers (lightmake.site envelope format) ------------

/// Raw skill entry as returned by the lightmake.site `/api/skills` endpoint.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawSkillEntry {
    pub slug: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub description_zh: String,
    #[serde(default)]
    pub category: String,
    #[serde(default, alias = "ownerName")]
    pub owner_name: String,
    #[serde(default)]
    pub downloads: u64,
    #[serde(default)]
    pub installs: u64,
    #[serde(default)]
    pub stars: u64,
    #[serde(default)]
    pub score: f64,
    #[serde(default)]
    pub version: String,
    #[serde(default)]
    pub homepage: String,
    #[serde(default)]
    pub updated_at: i64,
    #[serde(default)]
    pub tags: Option<serde_json::Value>,
}

/// Envelope for the `/api/skills` and `/api/skills/top` responses.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawSkillsEnvelope {
    #[serde(default)]
    pub code: i32,
    #[serde(default)]
    pub data: RawSkillsData,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct RawSkillsData {
    #[serde(default)]
    pub skills: Vec<RawSkillEntry>,
}

// -- Browse: GET /api/skills?limit=N&sort=trending -------------------------

/// A skill entry exposed to the rest of the codebase.
///
/// Mapped from the raw `RawSkillEntry` returned by lightmake.site.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClawHubBrowseEntry {
    pub slug: String,
    #[serde(default)]
    pub display_name: String,
    #[serde(default)]
    pub summary: String,
    /// Version tags (e.g. `{"latest": "1.0.0"}`).
    #[serde(default)]
    pub tags: std::collections::HashMap<String, String>,
    #[serde(default)]
    pub stats: ClawHubStats,
    /// Unix ms timestamp.
    #[serde(default)]
    pub created_at: i64,
    /// Unix ms timestamp.
    #[serde(default)]
    pub updated_at: i64,
    #[serde(default)]
    pub latest_version: Option<ClawHubVersionInfo>,
}

impl From<RawSkillEntry> for ClawHubBrowseEntry {
    fn from(raw: RawSkillEntry) -> Self {
        let mut tags = std::collections::HashMap::new();
        if !raw.version.is_empty() {
            tags.insert("latest".to_string(), raw.version.clone());
        }
        Self {
            slug: raw.slug,
            display_name: raw.name,
            summary: raw.description,
            tags,
            stats: ClawHubStats {
                downloads: raw.downloads,
                stars: raw.stars,
                installs_all_time: raw.installs,
                installs_current: raw.installs,
                ..Default::default()
            },
            created_at: 0,
            updated_at: raw.updated_at,
            latest_version: if raw.version.is_empty() {
                None
            } else {
                Some(ClawHubVersionInfo {
                    version: raw.version,
                    created_at: raw.updated_at,
                    changelog: String::new(),
                })
            },
        }
    }
}

/// Paginated response from the browse endpoint.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClawHubBrowseResponse {
    pub items: Vec<ClawHubBrowseEntry>,
    #[serde(default)]
    pub next_cursor: Option<String>,
}

// -- Search: uses the same /api/skills endpoint with `q` parameter ---------

/// A skill entry from the search endpoint.
///
/// Mapped from `RawSkillEntry` for backward compatibility.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClawHubSearchEntry {
    #[serde(default)]
    pub score: f64,
    pub slug: String,
    #[serde(default)]
    pub display_name: String,
    #[serde(default)]
    pub summary: String,
    #[serde(default)]
    pub version: Option<String>,
    /// Unix ms timestamp.
    #[serde(default)]
    pub updated_at: i64,
}

impl From<RawSkillEntry> for ClawHubSearchEntry {
    fn from(raw: RawSkillEntry) -> Self {
        Self {
            score: raw.score,
            slug: raw.slug,
            display_name: raw.name,
            summary: raw.description,
            version: if raw.version.is_empty() {
                None
            } else {
                Some(raw.version)
            },
            updated_at: raw.updated_at,
        }
    }
}

/// Response from the search endpoint.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClawHubSearchResponse {
    pub results: Vec<ClawHubSearchEntry>,
}

// -- Detail: synthesized from browse data ----------------------------------

/// The `skill` object nested inside the detail response.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClawHubSkillInfo {
    pub slug: String,
    #[serde(default)]
    pub display_name: String,
    #[serde(default)]
    pub summary: String,
    #[serde(default)]
    pub tags: std::collections::HashMap<String, String>,
    #[serde(default)]
    pub stats: ClawHubStats,
    #[serde(default)]
    pub created_at: i64,
    #[serde(default)]
    pub updated_at: i64,
}

/// Full detail response for a skill.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClawHubSkillDetail {
    pub skill: ClawHubSkillInfo,
    #[serde(default)]
    pub latest_version: Option<ClawHubVersionInfo>,
    #[serde(default)]
    pub owner: Option<ClawHubOwner>,
    /// Moderation status (null when clean).
    #[serde(default)]
    pub moderation: Option<serde_json::Value>,
}

impl From<RawSkillEntry> for ClawHubSkillDetail {
    fn from(raw: RawSkillEntry) -> Self {
        let mut tags = std::collections::HashMap::new();
        if !raw.version.is_empty() {
            tags.insert("latest".to_string(), raw.version.clone());
        }
        let owner = if raw.owner_name.is_empty() {
            None
        } else {
            Some(ClawHubOwner {
                handle: raw.owner_name.clone(),
                display_name: raw.owner_name,
                ..Default::default()
            })
        };
        Self {
            skill: ClawHubSkillInfo {
                slug: raw.slug,
                display_name: raw.name,
                summary: raw.description,
                tags,
                stats: ClawHubStats {
                    downloads: raw.downloads,
                    stars: raw.stars,
                    installs_all_time: raw.installs,
                    installs_current: raw.installs,
                    ..Default::default()
                },
                created_at: 0,
                updated_at: raw.updated_at,
            },
            latest_version: if raw.version.is_empty() {
                None
            } else {
                Some(ClawHubVersionInfo {
                    version: raw.version,
                    created_at: raw.updated_at,
                    changelog: String::new(),
                })
            },
            owner,
            moderation: None,
        }
    }
}

// -- Sort enum -------------------------------------------------------------

/// Sort order for browsing skills.
#[derive(Debug, Clone, Copy)]
pub enum ClawHubSort {
    Trending,
    Updated,
    Downloads,
    Stars,
    Rating,
}

impl ClawHubSort {
    fn as_str(self) -> &'static str {
        match self {
            Self::Trending => "trending",
            Self::Updated => "updated",
            Self::Downloads => "downloads",
            Self::Stars => "stars",
            Self::Rating => "rating",
        }
    }
}

// -- Backward compat aliases -----------------------------------------------

/// Alias kept for code that still references the old name.
pub type ClawHubListResponse = ClawHubBrowseResponse;
/// Alias kept for code that still references the old name.
pub type ClawHubSearchResults = ClawHubSearchResponse;
/// Alias kept for code that still references the old name.
pub type ClawHubEntry = ClawHubBrowseEntry;

/// Result of installing a skill from ClawHub.
#[derive(Debug, Clone)]
pub struct ClawHubInstallResult {
    /// Installed skill name.
    pub skill_name: String,
    /// Installed version.
    pub version: String,
    /// The skill slug on ClawHub.
    pub slug: String,
    /// Security warnings from the scan pipeline.
    pub warnings: Vec<SkillWarning>,
    /// Tool name translations applied (OpenClaw → OpenFang).
    pub tool_translations: Vec<(String, String)>,
    /// Whether this is a prompt-only skill.
    pub is_prompt_only: bool,
}

/// Client for the SkillHub marketplace (skillhub.tencent.com).
pub struct ClawHubClient {
    /// Base URL for the ClawHub API.
    base_url: String,
/// Optional fallback URL (original skillhub.tencent.com when using a mirror as primary).
    fallback_url: Option<String>,
    /// HTTP client.
    client: reqwest::Client,
    /// Local cache directory for downloaded skills.
    _cache_dir: PathBuf,
}

/// Default official SkillHub API URL (lightmake.site backend).
const CLAWHUB_OFFICIAL_URL: &str = "https://lightmake.site";

/// Download endpoint base (still uses /api/v1 path).
const CLAWHUB_DOWNLOAD_URL: &str = "https://lightmake.site";

impl ClawHubClient {
    /// Create a new SkillHub client with default settings.
    ///
    /// Uses the official SkillHub API at `https://skillhub.tencent.com/api/v1`.
    pub fn new(cache_dir: PathBuf) -> Self {
        Self::with_url(CLAWHUB_OFFICIAL_URL, cache_dir)
    }

    /// Create a ClawHub client with a mirror URL as the primary endpoint.
    ///
    /// When the mirror is set, all requests go to the mirror first.
    /// If the mirror fails (timeout, 5xx, connection error), the client
    /// automatically retries against the official lightmake.site.
    pub fn with_mirror(mirror_url: &str, cache_dir: PathBuf) -> Self {
        let mirror = mirror_url.trim_end_matches('/');
        let is_official = mirror == CLAWHUB_OFFICIAL_URL
            || mirror == "https://lightmake.site/"
            || mirror == "https://skillhub.tencent.com/api/v1"
            || mirror == "https://skillhub.tencent.com/api/v1/";
        Self {
            base_url: mirror.to_string(),
            fallback_url: if is_official {
                None
            } else {
                Some(CLAWHUB_OFFICIAL_URL.to_string())
            },
            client: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(30))
                .build()
                .unwrap_or_default(),
            _cache_dir: cache_dir,
        }
    }

    /// Create a ClawHub client with a custom API URL (no fallback).
    pub fn with_url(base_url: &str, cache_dir: PathBuf) -> Self {
        Self {
            base_url: base_url.trim_end_matches('/').to_string(),
            fallback_url: None,
            client: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(30))
                .build()
                .unwrap_or_default(),
            _cache_dir: cache_dir,
        }
    }

    /// Make a GET request with automatic mirror→fallback retry.
    ///
    /// Tries the primary (mirror) URL first. If it fails with a transient
    /// error (timeout, connection refused, 429, 5xx), retries once against
    /// the fallback (official) URL.
    async fn get_with_fallback(&self, path: &str) -> Result<reqwest::Response, SkillError> {
        let primary_url = format!("{}{}", self.base_url, path);

        let primary_result = self
            .client
            .get(&primary_url)
            .header("User-Agent", "OpenFang/0.1")
            .send()
            .await;

        match &primary_result {
            Ok(resp) if resp.status().is_success() || resp.status().is_client_error() => {
                // 2xx or 4xx (not 429) → use this response directly
                if resp.status().as_u16() != 429 {
                    return primary_result.map_err(|e| {
                        SkillError::Network(format!("ClawHub request failed: {e}"))
                    });
                }
                // 429 rate limited → fall through to fallback
                info!(url = %primary_url, "Mirror returned 429, trying fallback");
            }
            Ok(resp) => {
                // 5xx → fall through to fallback
                info!(url = %primary_url, status = %resp.status(), "Mirror returned server error, trying fallback");
            }
            Err(e) => {
                // Timeout / connection error → fall through to fallback
                info!(url = %primary_url, error = %e, "Mirror unreachable, trying fallback");
            }
        }

        // Try fallback if available
        if let Some(fallback) = &self.fallback_url {
            let fallback_url = format!("{}{}", fallback, path);
            info!(url = %fallback_url, "Retrying with fallback URL");
            self.client
                .get(&fallback_url)
                .header("User-Agent", "OpenFang/0.1")
                .send()
                .await
                .map_err(|e| SkillError::Network(format!("ClawHub fallback also failed: {e}")))
        } else {
            // No fallback — return original error
            primary_result
                .map_err(|e| SkillError::Network(format!("ClawHub request failed: {e}")))
        }
    }

    /// Search for skills on ClawHub.
    ///
    /// Uses `GET /api/skills?q=...&limit=...&sort=trending`.
    /// The search endpoint is the same as browse but with a `q` parameter.
    pub async fn search(
        &self,
        query: &str,
        limit: u32,
    ) -> Result<ClawHubSearchResponse, SkillError> {
        let path = format!(
            "/api/skills?q={}&limit={}&sort=trending",
            urlencoded(query),
            limit.min(50)
        );

        let response = self.get_with_fallback(&path).await?;

        if !response.status().is_success() {
            return Err(SkillError::Network(format!(
                "ClawHub API returned {}",
                response.status()
            )));
        }

        let envelope: RawSkillsEnvelope = response
            .json()
            .await
            .map_err(|e| SkillError::Network(format!("Failed to parse ClawHub response: {e}")))?;

        let results: Vec<ClawHubSearchEntry> = envelope
            .data
            .skills
            .into_iter()
            .map(ClawHubSearchEntry::from)
            .collect();

        Ok(ClawHubSearchResponse { results })
    }

    /// Browse skills by sort order (trending, downloads, stars, etc.).
    ///
    /// Uses `GET /api/skills?limit=...&sort=...`.
    pub async fn browse(
        &self,
        sort: ClawHubSort,
        limit: u32,
        cursor: Option<&str>,
    ) -> Result<ClawHubBrowseResponse, SkillError> {
        let mut path = format!(
            "/api/skills?limit={}&sort={}",
            limit.min(50),
            sort.as_str()
        );

        if let Some(c) = cursor {
            path.push_str(&format!("&cursor={}", urlencoded(c)));
        }

        let response = self.get_with_fallback(&path).await?;

        if !response.status().is_success() {
            return Err(SkillError::Network(format!(
                "ClawHub browse returned {}",
                response.status()
            )));
        }

        let envelope: RawSkillsEnvelope = response
            .json()
            .await
            .map_err(|e| SkillError::Network(format!("Failed to parse ClawHub browse: {e}")))?;

        let items: Vec<ClawHubBrowseEntry> = envelope
            .data
            .skills
            .into_iter()
            .map(ClawHubBrowseEntry::from)
            .collect();

        Ok(ClawHubBrowseResponse {
            items,
            next_cursor: None,
        })
    }

    /// Get detailed info about a specific skill.
    ///
    /// Fetches from `GET /api/skills?q={slug}&limit=1` and maps the result.
    /// Falls back to constructing detail from the browse data.
    pub async fn get_skill(&self, slug: &str) -> Result<ClawHubSkillDetail, SkillError> {
        let path = format!("/api/skills?q={}&limit=1", urlencoded(slug));

        let response = self.get_with_fallback(&path).await?;

        if !response.status().is_success() {
            return Err(SkillError::Network(format!(
                "ClawHub detail returned {}",
                response.status()
            )));
        }

        let envelope: RawSkillsEnvelope = response
            .json()
            .await
            .map_err(|e| SkillError::Network(format!("Failed to parse ClawHub detail: {e}")))?;

        // Find exact slug match in results
        let raw_entry = envelope
            .data
            .skills
            .into_iter()
            .find(|s| s.slug == slug)
            .ok_or_else(|| SkillError::Network(format!("Skill '{slug}' not found on ClawHub")))?;

        Ok(ClawHubSkillDetail::from(raw_entry))
    }

    /// Helper: extract the version string from a browse entry.
    pub fn entry_version(entry: &ClawHubBrowseEntry) -> &str {
        entry
            .latest_version
            .as_ref()
            .map(|v| v.version.as_str())
            .or_else(|| entry.tags.get("latest").map(|s| s.as_str()))
            .unwrap_or("")
    }

    /// Fetch a specific file from a skill (e.g., SKILL.md, README).
    ///
    /// Uses `GET /api/v1/skills/{slug}/file?path=SKILL.md` on the download backend.
    pub async fn get_file(&self, slug: &str, file_path: &str) -> Result<String, SkillError> {
        let path = format!(
            "/api/v1/skills/{}/file?path={}",
            urlencoded(slug),
            urlencoded(file_path)
        );

        // Use the download backend URL for file access
        let file_url = format!("{}{}", CLAWHUB_DOWNLOAD_URL, path);

        // Retry with exponential backoff on 429/5xx
        let mut last_err = String::new();
        let mut bytes_result = None;
        for attempt in 0..3u32 {
            if attempt > 0 {
                let delay = std::time::Duration::from_millis(1000 * 2u64.pow(attempt));
                tokio::time::sleep(delay).await;
                info!(slug, attempt, "Retrying ClawHub file fetch");
            }
            let response = self
                .client
                .get(&file_url)
                .header("User-Agent", "OpenFang/0.1")
                .send()
                .await
                .map_err(|e| SkillError::Network(format!("ClawHub file request failed: {e}")))?;

            if !response.status().is_success() {
                if response.status().as_u16() == 429 || response.status().is_server_error() {
                    last_err = format!("ClawHub download returned {}", response.status());
                    continue;
                }
                return Err(SkillError::Network(format!(
                    "ClawHub download returned {}",
                    response.status()
                )));
            }

            match response.bytes().await {
                Ok(b) => {
                    bytes_result = Some(b);
                    break;
                }
                Err(e) => last_err = format!("Failed to read download: {e}"),
            }
        }
        let bytes = bytes_result
            .ok_or_else(|| SkillError::Network(format!("{last_err} (after 3 attempts)")))?;
        let text = String::from_utf8_lossy(&bytes).to_string();
        Ok(text)
    }

    /// Install a skill from ClawHub into the target directory.
    ///
    /// Security pipeline:
    /// 1. Download skill zip and compute SHA256
    /// 2. Detect format (SKILL.md vs package.json)
    /// 3. Convert to OpenFang manifest
    /// 4. Run manifest security scan
    /// 5. If prompt-only: run prompt injection scan
    /// 6. Check binary dependencies
    /// 7. Write skill.toml with `verified: false`
    pub async fn install(
        &self,
        slug: &str,
        target_dir: &Path,
    ) -> Result<ClawHubInstallResult, SkillError> {
        // Use /api/v1/download?slug=... endpoint on download backend
        let path = format!("/api/v1/download?slug={}", urlencoded(slug));
        let download_url = format!("{}{}", CLAWHUB_DOWNLOAD_URL, path);

        info!(slug, "Downloading skill from ClawHub");

        // Retry with exponential backoff on 429/5xx
        let mut last_err = String::new();
        let mut bytes_result = None;
        for attempt in 0..3u32 {
            if attempt > 0 {
                let delay = std::time::Duration::from_millis(1000 * 2u64.pow(attempt));
                tokio::time::sleep(delay).await;
                info!(slug, attempt, "Retrying ClawHub download");
            }
            let response = self
                .client
                .get(&download_url)
                .header("User-Agent", "OpenFang/0.1")
                .send()
                .await
                .map_err(|e| SkillError::Network(format!("ClawHub download failed: {e}")))?;

            if !response.status().is_success() {
                if response.status().as_u16() == 429 || response.status().is_server_error() {
                    last_err = format!("ClawHub download returned {}", response.status());
                    continue;
                }
                return Err(SkillError::Network(format!(
                    "ClawHub download returned {}",
                    response.status()
                )));
            }

            match response.bytes().await {
                Ok(b) => {
                    bytes_result = Some(b);
                    break;
                }
                Err(e) => last_err = format!("Failed to read download: {e}"),
            }
        }
        let bytes = bytes_result
            .ok_or_else(|| SkillError::Network(format!("{last_err} (after 3 attempts)")))?;

        // Step 1: SHA256 of downloaded content
        let sha256 = {
            let mut hasher = Sha256::new();
            hasher.update(&bytes);
            hex::encode(hasher.finalize())
        };
        info!(slug, sha256 = %sha256, "Downloaded skill");

        // Create skill directory
        let skill_dir = target_dir.join(slug);
        std::fs::create_dir_all(&skill_dir)?;

        // Detect content type and extract accordingly
        let content_str = String::from_utf8_lossy(&bytes);
        let is_skillmd = content_str.trim_start().starts_with("---");

        if is_skillmd {
            std::fs::write(skill_dir.join("SKILL.md"), &*bytes)?;
        } else if bytes.len() >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4b {
            // Zip archive — extract all files
            let cursor = std::io::Cursor::new(&*bytes);
            match zip::ZipArchive::new(cursor) {
                Ok(mut archive) => {
                    for i in 0..archive.len() {
                        let mut file = match archive.by_index(i) {
                            Ok(f) => f,
                            Err(e) => {
                                warn!(index = i, error = %e, "Skipping zip entry");
                                continue;
                            }
                        };
                        let Some(enclosed_name) = file.enclosed_name() else {
                            warn!("Skipping zip entry with unsafe path");
                            continue;
                        };
                        let out_path = skill_dir.join(enclosed_name);
                        if file.is_dir() {
                            std::fs::create_dir_all(&out_path)?;
                        } else {
                            if let Some(parent) = out_path.parent() {
                                std::fs::create_dir_all(parent)?;
                            }
                            let mut out_file = std::fs::File::create(&out_path)?;
                            std::io::copy(&mut file, &mut out_file)?;
                        }
                    }
                    info!(slug, entries = archive.len(), "Extracted skill zip");
                }
                Err(e) => {
                    warn!(slug, error = %e, "Failed to read zip, saving raw");
                    std::fs::write(skill_dir.join("skill.zip"), &*bytes)?;
                }
            }
        } else {
            std::fs::write(skill_dir.join("package.json"), &*bytes)?;
        }

        // Step 2-3: Detect format and convert
        let mut all_warnings = Vec::new();
        let mut tool_translations = Vec::new();
        let mut is_prompt_only = false;

        let manifest = if is_skillmd || openclaw_compat::detect_skillmd(&skill_dir) {
            let converted = openclaw_compat::convert_skillmd(&skill_dir)?;
            tool_translations = converted.tool_translations;
            is_prompt_only =
                converted.manifest.runtime.runtime_type == crate::SkillRuntime::PromptOnly;

            // Step 5: Prompt injection scan
            let prompt_warnings = SkillVerifier::scan_prompt_content(&converted.prompt_context);
            if prompt_warnings
                .iter()
                .any(|w| w.severity == WarningSeverity::Critical)
            {
                // Block installation of skills with critical prompt injection
                let critical_msgs: Vec<_> = prompt_warnings
                    .iter()
                    .filter(|w| w.severity == WarningSeverity::Critical)
                    .map(|w| w.message.clone())
                    .collect();

                // Clean up skill directory on blocked install
                let _ = std::fs::remove_dir_all(&skill_dir);

                return Err(SkillError::SecurityBlocked(format!(
                    "Skill blocked due to prompt injection: {}",
                    critical_msgs.join("; ")
                )));
            }
            all_warnings.extend(prompt_warnings);

            // Write prompt context
            openclaw_compat::write_prompt_context(&skill_dir, &converted.prompt_context)?;

            // Step 6: Binary dependency check
            for bin in &converted.required_bins {
                if which_check(bin).is_none() {
                    all_warnings.push(SkillWarning {
                        severity: WarningSeverity::Warning,
                        message: format!("Required binary not found: {bin}"),
                    });
                }
            }

            converted.manifest
        } else if openclaw_compat::detect_openclaw_skill(&skill_dir) {
            openclaw_compat::convert_openclaw_skill(&skill_dir)?
        } else {
            return Err(SkillError::InvalidManifest(
                "Downloaded content is not a recognized skill format".to_string(),
            ));
        };

        // Step 4: Manifest security scan
        let manifest_warnings = SkillVerifier::security_scan(&manifest);
        all_warnings.extend(manifest_warnings);

        // Step 4b: Set source provenance to ClawHub
        let mut manifest = manifest;
        manifest.source = Some(crate::SkillSource::ClawHub {
            slug: slug.to_string(),
            version: manifest.skill.version.clone(),
        });

        // Step 7: Write skill.toml
        openclaw_compat::write_openfang_manifest(&skill_dir, &manifest)?;

        let result = ClawHubInstallResult {
            skill_name: manifest.skill.name.clone(),
            version: manifest.skill.version.clone(),
            slug: slug.to_string(),
            warnings: all_warnings,
            tool_translations,
            is_prompt_only,
        };

        info!(
            slug,
            skill_name = %result.skill_name,
            warnings = result.warnings.len(),
            "Installed skill from ClawHub"
        );

        Ok(result)
    }

    /// Check if a ClawHub skill is already installed locally.
    pub fn is_installed(&self, slug: &str, skills_dir: &Path) -> bool {
        let skill_dir = skills_dir.join(slug);
        skill_dir.join("skill.toml").exists()
    }
}

/// RFC 3986 percent-encoding for query parameters.
/// Unreserved characters pass through, space becomes `+`, everything else is `%XX`.
fn urlencoded(s: &str) -> String {
    const HEX_UPPER: &[u8; 16] = b"0123456789ABCDEF";
    let mut result = String::with_capacity(s.len() * 3);
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                result.push(b as char);
            }
            b' ' => result.push('+'),
            _ => {
                result.push('%');
                result.push(HEX_UPPER[(b >> 4) as usize] as char);
                result.push(HEX_UPPER[(b & 0xf) as usize] as char);
            }
        }
    }
    result
}

/// Check if a binary is available on PATH.
fn which_check(name: &str) -> Option<PathBuf> {
    let result = if cfg!(target_os = "windows") {
        std::process::Command::new("where").arg(name).output()
    } else {
        std::process::Command::new("which").arg(name).output()
    };

    match result {
        Ok(output) if output.status.success() => {
            let path_str = String::from_utf8_lossy(&output.stdout);
            let first_line = path_str.lines().next()?;
            Some(PathBuf::from(first_line.trim()))
        }
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_browse_entry_serde_real_format() {
        // Matches actual lightmake.site API response (verified Mar 2026)
        let json = r#"{
            "slug": "video-cog",
            "name": "video-cog",
            "description": "Long-form AI video production.",
            "description_zh": "长视频AI制作",
            "category": "content-creation",
            "ownerName": "nitishgargiitd",
            "downloads": 5210,
            "installs": 157,
            "stars": 20,
            "score": 2307.93,
            "version": "1.0.3",
            "homepage": "https://clawhub.ai/nitishgargiitd/video-cog",
            "updated_at": 1774001468614,
            "tags": null
        }"#;

        let raw: RawSkillEntry = serde_json::from_str(json).unwrap();
        assert_eq!(raw.slug, "video-cog");
        assert_eq!(raw.name, "video-cog");
        assert_eq!(raw.downloads, 5210);
        assert_eq!(raw.stars, 20);

        let entry = ClawHubBrowseEntry::from(raw);
        assert_eq!(entry.slug, "video-cog");
        assert_eq!(entry.display_name, "video-cog");
        assert_eq!(entry.summary, "Long-form AI video production.");
        assert_eq!(entry.stats.downloads, 5210);
        assert_eq!(entry.stats.stars, 20);
        assert_eq!(entry.tags.get("latest").unwrap(), "1.0.3");
        assert_eq!(entry.latest_version.as_ref().unwrap().version, "1.0.3");
        assert_eq!(entry.updated_at, 1774001468614);
    }

    #[test]
    fn test_browse_response_envelope_serde() {
        let json = r#"{
            "code": 0,
            "data": {
                "skills": [{
                    "slug": "test",
                    "name": "Test",
                    "description": "A test",
                    "downloads": 100,
                    "stars": 5,
                    "version": "1.0.0",
                    "updated_at": 0,
                    "tags": null
                }]
            }
        }"#;

        let envelope: RawSkillsEnvelope = serde_json::from_str(json).unwrap();
        assert_eq!(envelope.code, 0);
        assert_eq!(envelope.data.skills.len(), 1);
        assert_eq!(envelope.data.skills[0].slug, "test");
        assert_eq!(envelope.data.skills[0].downloads, 100);
    }

    #[test]
    fn test_search_entry_from_raw() {
        // Matches actual lightmake.site search response (verified Mar 2026)
        let json = r#"{
            "slug": "github",
            "name": "Github",
            "description": "Interact with GitHub using the gh CLI.",
            "downloads": 114714,
            "stars": 376,
            "score": 43400.64,
            "version": "1.0.0",
            "updated_at": 1774001395822
        }"#;

        let raw: RawSkillEntry = serde_json::from_str(json).unwrap();
        let entry = ClawHubSearchEntry::from(raw);
        assert_eq!(entry.slug, "github");
        assert_eq!(entry.display_name, "Github");
        assert!(entry.score > 43000.0);
        assert_eq!(entry.version.as_deref(), Some("1.0.0"));
        assert_eq!(entry.updated_at, 1774001395822);
    }

    #[test]
    fn test_search_response_serde() {
        // ClawHubSearchResponse is constructed programmatically, not from API directly
        let resp = ClawHubSearchResponse {
            results: vec![ClawHubSearchEntry {
                score: 3.5,
                slug: "test".to_string(),
                display_name: "Test".to_string(),
                summary: "A test".to_string(),
                version: Some("0.1.0".to_string()),
                updated_at: 0,
            }],
        };

        assert_eq!(resp.results.len(), 1);
        assert_eq!(resp.results[0].slug, "test");
    }

    #[test]
    fn test_skill_detail_from_raw() {
        // Test converting a raw entry to a ClawHubSkillDetail
        let json = r#"{
            "slug": "github",
            "name": "Github",
            "description": "Interact with GitHub using the gh CLI.",
            "downloads": 114714,
            "stars": 376,
            "score": 43400.64,
            "version": "1.0.0",
            "ownerName": "steipete",
            "updated_at": 1774001395822
        }"#;

        let raw: RawSkillEntry = serde_json::from_str(json).unwrap();
        let detail = ClawHubSkillDetail::from(raw);
        assert_eq!(detail.skill.slug, "github");
        assert_eq!(detail.skill.display_name, "Github");
        assert_eq!(detail.skill.stats.downloads, 114714);
        assert_eq!(detail.skill.stats.stars, 376);
        assert_eq!(detail.latest_version.as_ref().unwrap().version, "1.0.0");
        assert_eq!(detail.owner.as_ref().unwrap().handle, "steipete");
        assert!(detail.moderation.is_none());
    }

    #[test]
    fn test_clawhub_install_result() {
        let result = ClawHubInstallResult {
            skill_name: "test-skill".to_string(),
            version: "1.0.0".to_string(),
            slug: "test-skill".to_string(),
            warnings: vec![],
            tool_translations: vec![("Read".to_string(), "file_read".to_string())],
            is_prompt_only: true,
        };

        assert_eq!(result.skill_name, "test-skill");
        assert!(result.is_prompt_only);
        assert_eq!(result.tool_translations.len(), 1);
    }

    #[test]
    fn test_urlencoded() {
        assert_eq!(urlencoded("hello world"), "hello+world");
        assert_eq!(urlencoded("a&b=c"), "a%26b%3Dc");
        assert_eq!(urlencoded("path/to#frag"), "path%2Fto%23frag");
        // Previously missed characters
        assert_eq!(urlencoded("100%"), "100%25");
        assert_eq!(urlencoded("a+b"), "a%2Bb");
        // Unreserved chars pass through
        assert_eq!(urlencoded("hello-world_2.0~test"), "hello-world_2.0~test");
    }

    #[test]
    fn test_clawhub_sort_str() {
        assert_eq!(ClawHubSort::Trending.as_str(), "trending");
        assert_eq!(ClawHubSort::Downloads.as_str(), "downloads");
        assert_eq!(ClawHubSort::Stars.as_str(), "stars");
    }

    #[test]
    fn test_clawhub_client_url() {
        let client = ClawHubClient::new(PathBuf::from("/tmp/cache"));
        assert_eq!(client.base_url, CLAWHUB_OFFICIAL_URL);
        assert!(client.fallback_url.is_none());
    }

    #[test]
    fn test_clawhub_client_with_mirror() {
        let client = ClawHubClient::with_mirror(
            "https://mirror.example.com/api/v1",
            PathBuf::from("/tmp/cache"),
        );
        assert_eq!(client.base_url, "https://mirror.example.com/api/v1");
        assert_eq!(client.fallback_url.as_deref(), Some(CLAWHUB_OFFICIAL_URL));
    }

    #[test]
    fn test_clawhub_client_mirror_same_as_official() {
        // When mirror URL is the same as official, no fallback needed
        let client = ClawHubClient::with_mirror(
            "https://lightmake.site",
            PathBuf::from("/tmp/cache"),
        );
        assert_eq!(client.base_url, CLAWHUB_OFFICIAL_URL);
        assert!(client.fallback_url.is_none());
    }

    #[test]
    fn test_clawhub_client_old_skillhub_url_is_official() {
        // Old skillhub.tencent.com URL should also be treated as official
        let client = ClawHubClient::with_mirror(
            "https://skillhub.tencent.com/api/v1",
            PathBuf::from("/tmp/cache"),
        );
        assert_eq!(client.base_url, CLAWHUB_OFFICIAL_URL);
        assert!(client.fallback_url.is_none());
    }

    #[test]
    fn test_entry_version_helper() {
        let entry = ClawHubBrowseEntry {
            slug: "test".to_string(),
            display_name: "Test".to_string(),
            summary: String::new(),
            tags: [("latest".to_string(), "2.0.0".to_string())]
                .into_iter()
                .collect(),
            stats: ClawHubStats::default(),
            created_at: 0,
            updated_at: 0,
            latest_version: Some(ClawHubVersionInfo {
                version: "2.0.0".to_string(),
                created_at: 0,
                changelog: String::new(),
            }),
        };
        assert_eq!(ClawHubClient::entry_version(&entry), "2.0.0");
    }
}
