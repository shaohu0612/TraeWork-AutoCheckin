const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// 解密算法常量
const HP = 16, q8_AES128 = 16, WP = HP, rh = 64, Rv = 32, VP = 64, Em = 6;
const ure = Uint8Array.from([82,9,106,213,48,54,165,56,191,64,163,158,129,243,215,251,124,227,57,130,155,47,255,135,52,142,67,68,196,222,233,203,84,123,148,50,166,194,35,61,238,76,149,11,66,250,195,78,8,46,161,102,40,217,36,178,118,91,162,73,109,139,209,37]);
const dre = Uint8Array.from([31,221,168,51,136,7,199,49,177,18,16,89,39,128,236,95,96,81,127,169,25,181,74,13,45,229,122,159,147,201,156,239,160,224,59,77,174,42,245,176,200,235,187,60,131,83,153,97,23,43,4,126,186,119,214,38,225,105,20,99,85,33,12,125]);

/**
 * 兼容不同 Node.js / Electron 版本的 WebCrypto Subtle 接口获取
 */
function getSubtleCrypto() {
  if (typeof crypto !== 'undefined' && crypto.subtle) return crypto.subtle;
  if (typeof crypto !== 'undefined' && crypto.webcrypto && crypto.webcrypto.subtle) return crypto.webcrypto.subtle;
  if (typeof globalThis !== 'undefined' && globalThis.crypto && globalThis.crypto.subtle) return globalThis.crypto.subtle;
  return null;
}

async function sha512(data) {
  const subtle = getSubtleCrypto();
  if (!subtle) {
    throw new Error('当前环境缺少 WebCrypto / subtle 模块支持，请确保使用 Node.js 18+ 或使用内置 Trae 运行时。');
  }
  const h = await subtle.digest('SHA-512', data);
  return new Uint8Array(h);
}

function xorArrays(a, b, n) {
  const r = new Uint8Array(n);
  for (let i = 0; i < n; i++) r[i] = a[i] ^ b[i];
  return r;
}

/**
 * 解密 storage.json 中的凭据信息
 */
async function decrypt(b64) {
  const subtle = getSubtleCrypto();
  if (!subtle) {
    throw new Error('当前环境缺少 WebCrypto / subtle 模块支持，请确保使用 Node.js 18+ 或使用内置 Trae 运行时。');
  }
  const t = new Uint8Array(Buffer.from(b64, 'base64'));
  const key = t.slice(Em, Em + Rv);
  const sha = await sha512(key);
  const xor = xorArrays(ure, dre, VP);
  const comb = new Uint8Array(rh + VP);
  comb.set(sha, 0);
  comb.set(xor, rh);
  const hash = await sha512(comb);
  const aesKey = hash.slice(0, q8_AES128);
  const iv = hash.slice(q8_AES128, q8_AES128 + WP);
  const ct = t.slice(Rv + Em);
  const ck = await subtle.importKey('raw', aesKey, { name: 'AES-CBC' }, false, ['decrypt']);
  const dec = new Uint8Array(await subtle.decrypt({ name: 'AES-CBC', iv }, ck, ct));
  return new TextDecoder().decode(dec.slice(rh));
}

/**
 * 延时辅助函数
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * 获取各操作系统的应用配置根目录
 */
function getBaseConfigDir() {
  if (process.platform === 'win32') {
    return process.env.APPDATA || (process.env.USERPROFILE ? path.join(process.env.USERPROFILE, 'AppData', 'Roaming') : null);
  } else if (process.platform === 'darwin') {
    return process.env.HOME ? path.join(process.env.HOME, 'Library', 'Application Support') : null;
  } else {
    return process.env.XDG_CONFIG_HOME || (process.env.HOME ? path.join(process.env.HOME, '.config') : null);
  }
}

/**
 * 自动定位有效的 storage.json 路径
 */
function findStorageFile() {
  const baseDir = getBaseConfigDir();
  if (!baseDir) {
    throw new Error('未检测到用户配置目录环境变量（APPDATA 或 HOME）');
  }

  // 动态自动扫描配置目录下所有匹配 *trae* 的应用目录
  let candidateDirs = [];
  try {
    if (fs.existsSync(baseDir)) {
      const entries = fs.readdirSync(baseDir, { withFileTypes: true });
      candidateDirs = entries
        .filter(e => e.isDirectory() && e.name.toLowerCase().includes('trae'))
        .map(e => e.name);
    }
  } catch (e) {
    candidateDirs = [];
  }

  // 兜底保障常见命名目录
  const defaultDirs = ['Trae CN', 'TRAE SOLO CN', 'Trae', 'Trae%20CN', 'TraeCode CN', 'TraeCode'];
  for (const d of defaultDirs) {
    if (!candidateDirs.includes(d)) candidateDirs.push(d);
  }

  const candidates = [];

  for (const dir of candidateDirs) {
    const filePath = path.join(baseDir, dir, 'User', 'globalStorage', 'storage.json');
    if (fs.existsSync(filePath)) {
      try {
        const content = fs.readFileSync(filePath, 'utf8');
        const data = JSON.parse(content);
        if (data['iCubeAuthInfo://icube.cloudide']) {
          const stats = fs.statSync(filePath);
          candidates.push({ dirName: dir, path: filePath, data, mtime: stats.mtimeMs });
        }
      } catch (e) {
        // 忽略异常损坏的文件
      }
    }
  }

  if (candidates.length === 0) {
    throw new Error(
      `未在计算机中检测到任何有效的 Trae 登录凭据。\n` +
      `已扫描目录（包含 trae 的路径）：\n` +
      candidateDirs.map(d => `  - ${path.join(baseDir, d)}`).join('\n') +
      `\n请先打开并登录 Trae / TraeWork 客户端后再运行本程序。`
    );
  }

  // 按文件最后修改时间倒序排列，优先选择最新活跃的配置
  candidates.sort((a, b) => b.mtime - a.mtime);
  return candidates[0];
}

/**
 * 发送带重试机制的 HTTP 请求
 */
async function fetchWithRetry(url, options, maxRetries = 8) {
  const fetchFn = typeof fetch === 'function' ? fetch : (typeof globalThis !== 'undefined' && typeof globalThis.fetch === 'function' ? globalThis.fetch : null);
  if (!fetchFn) {
    throw new Error('当前环境缺少原生 fetch 支持，请使用 Node.js 18+ 或通过 run_checkin.cmd 运行内置 Trae 运行时。');
  }

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      // 15 秒请求超时保护，避免网络堵塞导致进程永久挂起
      const signal = typeof AbortSignal !== 'undefined' && typeof AbortSignal.timeout === 'function' ? AbortSignal.timeout(15000) : undefined;
      const requestOptions = signal ? { ...options, signal } : options;
      const res = await fetchFn(url, requestOptions);
      if (res.status === 429 || res.status >= 500) {
        throw new Error(`HTTP 状态码异常: ${res.status}`);
      }
      const data = await res.json();

      // 9074 代表服务器繁忙/限流，需要延时重试
      if (data.code === 9074) {
        if (attempt < maxRetries) {
          const delaySec = Math.floor(Math.random() * 15) + 12; // 随机 12~26 秒抖动，打散并发
          console.log(`[提示] 官方服务器繁忙限流 (Code 9074)，将在 ${delaySec} 秒后进行第 ${attempt}/${maxRetries} 次重试...`);
          await sleep(delaySec * 1000);
          continue;
        }
      }
      return data;
    } catch (err) {
      if (attempt < maxRetries) {
        const delaySec = 5 * attempt;
        console.log(`[提示] 请求异常 (${err.message})，将在 ${delaySec} 秒后重试 (${attempt}/${maxRetries})...`);
        await sleep(delaySec * 1000);
      } else {
        throw err;
      }
    }
  }
}

async function main() {
  console.log('=============================================');
  console.log('       TraeWork 每日自动签到程序');
  console.log('=============================================');

  // 1. 查找并读取存储文件
  const storageInfo = findStorageFile();
  console.log(`[1/3] 已定位配置文件: ${storageInfo.path}`);
  const storage = storageInfo.data;

  // 2. 解密认证信息
  const encryptedAuth = storage['iCubeAuthInfo://icube.cloudide'];
  let auth;
  try {
    const rawAuth = await decrypt(encryptedAuth);
    auth = JSON.parse(rawAuth);
  } catch (err) {
    console.log(`[错误] 解密登录态失败: ${err.message}`);
    return;
  }

  if (!auth.token) {
    console.log('[错误] 凭据中未找到 token，请在 Trae 客户端中重新登录。');
    return;
  }

  // 检查 Token 过期情况（若有）
  if (auth.expiredAt && auth.expiredAt * 1000 < Date.now()) {
    console.log('[警告] 当前登录态可能已过期，如果签到失败请重新打开 Trae 客户端刷新登录。');
  }

  // 3. 构建包含完整设备标识的请求头（防止 9004 参数错误）
  const headers = {
    'Authorization': `Cloud-IDE-JWT ${auth.token}`,
    'Content-Type': 'application/json',
    'X-Machine-Id': storage['telemetry.machineId'] || '',
    'X-Device-Id': storage['telemetry.devDeviceId'] || '',
    'X-User-Id': String(auth.userId || ''),
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Trae/1.0.0 Chrome/120.0.0.0 Electron/28.0.0 Safari/537.36'
  };
  if (auth.userRegion?.region) {
    headers['X-User-Region'] = auth.userRegion.region;
  }

  const maskedUserId = auth.userId ? `${String(auth.userId).slice(0, 6)}******` : '已获取';
  console.log(`[2/3] 凭据解析成功 (用户ID: ${maskedUserId}, 设备标识已关联)`);

  const statusUrl = 'https://api.trae.cn/trae/api/v2/ug/checkin_credits/status';
  const claimUrl = 'https://api.trae.cn/trae/api/v2/ug/checkin_credits/claim';

  // 4. 查询签到状态
  console.log('[3/3] 正在查询今日签到状态...');
  const status = await fetchWithRetry(statusUrl, {
    method: 'POST',
    headers,
    body: JSON.stringify({})
  }, 5);

  if (status.code !== 0 && status.code !== undefined) {
    console.log(`[错误] 查询签到状态失败 (Code: ${status.code}): ${status.message || '未知错误'}`);
    return;
  }

  const baseCredits = status.credits || 0;
  const extraCredits = status.extra_credits || 0;
  const totalCredits = baseCredits + extraCredits;

  if (status.checked_in) {
    const msg = `[已签到] 检测到今日已完成签到，自动跳过！累计积分: ${totalCredits} (基础: ${baseCredits}, 额外: ${extraCredits})`;
    console.log(`---------------------------------------------`);
    console.log(msg);
    console.log(`---------------------------------------------`);
    writeLog(msg);
    showNotification('TraeWork 签到提示', `今日已完成签到，自动跳过。\n累计获得: ${totalCredits} 积分 (官方消息: ${status.message || 'success'})`);
    return;
  }

  if (status.enable === false) {
    const msg = '[提示] 当前签到活动未开启或暂不可用。';
    console.log(msg);
    writeLog(msg);
    showNotification('TraeWork 签到提示', '当前签到活动未开启或暂不可用。');
    return;
  }

  // 5. 执行签到领取（最高重试 8 次，针对 9074 高峰限流自动退避）
  console.log(`[执行] 正在领取今日签到积分 (预计可得 ${totalCredits > 0 ? totalCredits : 200} 积分)...`);
  const claim = await fetchWithRetry(claimUrl, {
    method: 'POST',
    headers,
    body: JSON.stringify({})
  }, 8);

  if (claim.code === 0) {
    const claimedCredits = claim.data?.credits || totalCredits || 200;
    const msg = `[成功] 今日签到成功！成功领取 ${claimedCredits} 积分`;
    console.log(`---------------------------------------------`);
    console.log(msg);
    console.log(`---------------------------------------------`);
    writeLog(msg);
    showNotification('TraeWork 签到成功', `恭喜！成功领取 ${claimedCredits} 积分！\n官方返回消息: ${claim.message || 'success'}`);
  } else if (claim.code === 9074) {
    const msg = `[提示] 官方服务器繁忙限流 (Code: 9074: ${claim.message || '当前参与用户太多，请稍后再试'})。\n` +
      `       您的登录凭证与设备参数验证完全正常！此现象为官方接口高峰期限流保护。\n` +
      `       程序已自动重试多次。系统将在下一次开机或定时任务时自动继续签到，您也可稍后再次运行。`;
    console.log(`---------------------------------------------`);
    console.log(msg);
    console.log(`---------------------------------------------`);
    writeLog(`[限流] Code 9074: ${claim.message || '当前参与用户太多，请稍后再试'}`);
    showNotification('TraeWork 签到提示', `官方服务器繁忙 (Code 9074)，凭据正常，稍后将自动重试。`);
  } else {
    const msg = `[失败] 签到领取失败 (Code: ${claim.code}): ${claim.message || JSON.stringify(claim)}`;
    console.log(`---------------------------------------------`);
    console.log(msg);
    console.log(`---------------------------------------------`);
    writeLog(msg);
    showNotification('TraeWork 签到失败', `签到失败 (Code: ${claim.code})\n原因: ${claim.message || '未知错误'}`);
  }
}

function writeLog(text) {
  try {
    const logFile = path.join(__dirname, 'checkin.log');
    const now = new Date();
    const pad = n => String(n).padStart(2, '0');
    const timeStr = `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
    fs.appendFileSync(logFile, `[${timeStr}] ${text}\n`, 'utf8');
  } catch (e) {
    // 忽略日志文件写入异常
  }
}

/**
 * 弹出跨平台原生桌面消息通知（Windows / macOS / Linux）
 */
function showNotification(title, message) {
  try {
    const { execFile } = require('child_process');
    // 清洗字符，防止换行和特殊字符破坏脚本参数
    const cleanTitle = String(title).replace(/["`$]/g, '').replace(/\r?\n/g, ' ');
    const cleanMsg = String(message).replace(/["`$]/g, '').replace(/\r?\n/g, ' ');

    if (process.platform === 'win32') {
      const psCommand = `
        try {
          [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
          $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
          $textNodes = $template.GetElementsByTagName("text")
          $textNodes.Item(0).AppendChild($template.CreateTextNode("${cleanTitle}")) > $null
          $textNodes.Item(1).AppendChild($template.CreateTextNode("${cleanMsg}")) > $null
          $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("TraeWork")
          $notification = [Windows.UI.Notifications.ToastNotification]::new($template)
          $notifier.Show($notification)
        } catch {
          Add-Type -AssemblyName System.Windows.Forms
          $n = New-Object System.Windows.Forms.NotifyIcon
          $n.Icon = [System.Drawing.SystemIcons]::Information
          $n.BalloonTipTitle = "${cleanTitle}"
          $n.BalloonTipText = "${cleanMsg}"
          $n.Visible = $true
          $n.ShowBalloonTip(4000)
          Start-Sleep -Seconds 1
          $n.Dispose()
        }
      `;

      execFile('powershell', ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', psCommand], () => {});
    } else if (process.platform === 'darwin') {
      execFile('osascript', ['-e', `display notification "${cleanMsg}" with title "${cleanTitle}"`], () => {});
    } else if (process.platform === 'linux') {
      execFile('notify-send', [cleanTitle, cleanMsg], () => {});
    }
  } catch (e) {
    // 忽略通知异常，不影响核心流程
  }
}

main().catch(e => {
  const errMsg = `[异常] 程序执行失败: ${e.message}`;
  console.log(errMsg);
  writeLog(errMsg);
});
