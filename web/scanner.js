/*
 * 소망 도서관 — 책 바코드(ISBN) 인식
 *  - somangScanLive()        : 실시간 카메라 스캔 (전체화면 오버레이) → ISBN 문자열 또는 null
 *                              (ISBN 이 없는 잡지형 책은 '4193889712990-04' 같은 잡지 바코드+호수)
 *  - somangReadBarcodes(blob): 사진 한 장에서 바코드 읽기 → 문자열 배열
 * 인식 엔진: zxing-wasm (web/zxing, MIT) — 처음 쓸 때만 불러온다.
 * Dart 쪽: lib/services/photo_barcode.dart
 *
 * 갤럭시 등 후면 카메라가 여러 개인 폰은 브라우저가 초점이 고정된 광각 카메라를 고르는 경우가 있어
 * 메인 카메라("camera2 0, facing back")를 직접 고르고, 연속 자동초점·해상도를 요청한다.
 */
(function () {
  'use strict';

  var FORMATS = ['EAN-13', 'EAN-8', 'UPC-A'];
  var ready = null;

  function loadZXing() {
    if (ready) return ready;
    ready = new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = 'zxing/reader.js';
      s.onload = function () {
        ZXingWASM.prepareZXingModule({
          overrides: {
            locateFile: function (path, prefix) {
              return path.endsWith('.wasm')
                ? new URL('zxing/zxing_reader.wasm', document.baseURI).href
                : prefix + path;
            }
          }
        });
        resolve();
      };
      s.onerror = function () { ready = null; reject(new Error('바코드 인식 모듈을 불러오지 못했어요')); };
      document.head.appendChild(s);
    });
    return ready;
  }

  async function read(input, opts) {
    await loadZXing();
    var results = await ZXingWASM.readBarcodes(input, Object.assign({
      formats: FORMATS, tryHarder: true, maxNumberOfSymbols: 4,
      // 잡지 바코드 옆의 작은 2자리(호수)·5자리 부가 바코드도 같이 읽는다
      eanAddOnSymbol: 'Read'
    }, opts || {}));
    return results.filter(function (r) { return r.isValid; }).map(function (r) { return r.text; });
  }

  /** 978/979 로 시작하는 13자리 + 체크섬 (부가기호가 붙어도 앞 13자리) */
  function pickIsbn(texts) {
    for (var i = 0; i < texts.length; i++) {
      var digits = String(texts[i]).replace(/\D/g, '');
      var re = /97[89]\d{10}/g, m;
      while ((m = re.exec(digits))) {
        var s = m[0], sum = 0;
        for (var k = 0; k < 12; k++) sum += (+s[k]) * (k % 2 ? 3 : 1);
        if ((10 - sum % 10) % 10 === +s[12]) return s;
        re.lastIndex = m.index + 1;
      }
    }
    return null;
  }

  function validEan13(s) {
    var sum = 0;
    for (var k = 0; k < 12; k++) sum += (+s[k]) * (k % 2 ? 3 : 1);
    return (10 - sum % 10) % 10 === +s[12];
  }

  /**
   * ISBN 이 없는 잡지형 책(가판대용, 예: 미키마우스 LTB) 바코드
   * 독일 잡지 419·414, 국제 ISSN 977 + 옆의 2자리 호수 → '4193889712990-04' (호수를 못 읽으면 13자리만)
   * Dart BookLookupService.findPressCode 와 같은 규칙
   */
  function pickPress(texts) {
    var best = null;
    for (var i = 0; i < texts.length; i++) {
      var digits = String(texts[i]).replace(/\D/g, '');
      var m = /^(41[49]\d{10}|977\d{10})(\d{2}|\d{5})?$/.exec(digits);
      if (!m || !validEan13(m[1])) continue;
      if (m[2]) return m[1] + '-' + m[2];
      best = best || m[1];
    }
    return best;
  }

  window.somangReadBarcodes = function (blob) { return read(blob); };

  // ── 실시간 스캔 ───────────────────────────────────────────────────────────
  function el(tag, css, text) {
    var e = document.createElement(tag);
    if (css) e.style.cssText = css;
    if (text) e.textContent = text;
    return e;
  }

  function buildOverlay() {
    var root = el('div', 'position:fixed;inset:0;z-index:2147483000;background:#000;' +
      'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#fff;touch-action:none;');
    var video = el('video', 'position:absolute;inset:0;width:100%;height:100%;object-fit:cover;');
    video.setAttribute('playsinline', '');
    video.muted = true;
    var guide = el('div', 'position:absolute;left:50%;top:45%;width:min(86vw,420px);height:min(34vw,170px);' +
      'transform:translate(-50%,-50%);border:3px solid #fff;border-radius:14px;' +
      'box-shadow:0 0 0 9999px rgba(0,0,0,.45);');
    var line = el('div', 'position:absolute;left:8%;right:8%;top:50%;height:2px;background:#D6AA5A;opacity:.9;');
    guide.appendChild(line);
    var top = el('div', 'position:absolute;left:0;right:0;top:0;padding:max(14px,env(safe-area-inset-top)) 16px 14px;' +
      'display:flex;justify-content:space-between;align-items:center;');
    var title = el('div', 'font-size:18px;font-weight:600;', '바코드 스캔');
    var btns = el('div', 'display:flex;gap:10px;');
    var btnCss = 'background:rgba(255,255,255,.15);color:#fff;border:1px solid rgba(255,255,255,.4);' +
      'border-radius:22px;padding:9px 16px;font-size:15px;';
    var torch = el('button', btnCss + 'display:none;', '손전등');
    var close = el('button', btnCss, '닫기');
    btns.appendChild(torch); btns.appendChild(close);
    top.appendChild(title); top.appendChild(btns);
    var bottom = el('div', 'position:absolute;left:16px;right:16px;bottom:max(28px,env(safe-area-inset-bottom));' +
      'text-align:center;font-size:15px;line-height:1.5;');
    var msg = el('div', '', '책 뒷면 바코드를 네모 안에 맞춰 주세요.\n흐리면 조금 떨어뜨려 보세요.');
    msg.style.whiteSpace = 'pre-line';
    var last = el('div', 'margin-top:8px;font-size:12px;color:#ffd27a;min-height:16px;');
    bottom.appendChild(msg); bottom.appendChild(last);
    root.appendChild(video); root.appendChild(guide); root.appendChild(top); root.appendChild(bottom);
    document.body.appendChild(root);
    return { root: root, video: video, torch: torch, close: close, msg: msg, last: last, line: line };
  }

  /** 후면 메인 카메라 고르기 (권한을 받은 뒤라야 label 이 보인다) */
  async function pickBackCameraId() {
    var all = (await navigator.mediaDevices.enumerateDevices())
      .filter(function (d) { return d.kind === 'videoinput'; });
    var back = all.filter(function (d) { return /back|rear|environment|후면/i.test(d.label); });
    if (!back.length) return null;
    var main = back.find(function (d) { return /camera2 0\b|camera 0\b/i.test(d.label); });
    return (main || back[0]).deviceId;
  }

  async function openCamera() {
    var hd = { width: { ideal: 1920 }, height: { ideal: 1080 } };
    var stream = await navigator.mediaDevices.getUserMedia({
      audio: false, video: Object.assign({ facingMode: { ideal: 'environment' } }, hd)
    });
    try {
      var id = await pickBackCameraId();
      var cur = stream.getVideoTracks()[0].getSettings().deviceId;
      if (id && id !== cur) {
        stream.getTracks().forEach(function (t) { t.stop(); });
        stream = await navigator.mediaDevices.getUserMedia({
          audio: false, video: Object.assign({ deviceId: { exact: id } }, hd)
        });
      }
    } catch (_) { /* 처음 연 카메라 그대로 사용 */ }
    return stream;
  }

  window.somangScanLive = function () {
    return new Promise(function (resolve) {
      var ui = buildOverlay();
      var stream = null, stopped = false, timer = null, frame = 0, torchOn = false;
      var pressSeenAt = 0; // 호수 없이 잡지 바코드만 처음 읽힌 시각
      var canvas = document.createElement('canvas');
      var ctx = canvas.getContext('2d', { willReadFrequently: true });

      function finish(value) {
        if (stopped) return;
        stopped = true;
        clearTimeout(timer);
        if (stream) stream.getTracks().forEach(function (t) { t.stop(); });
        ui.root.remove();
        document.removeEventListener('visibilitychange', onHide);
        resolve(value);
      }
      function onHide() { if (document.hidden) finish(null); }
      document.addEventListener('visibilitychange', onHide);
      ui.close.onclick = function () { finish(null); };

      async function tick() {
        if (stopped) return;
        var v = ui.video;
        if (v.readyState >= 2 && v.videoWidth) {
          frame++;
          var vw = v.videoWidth, vh = v.videoHeight;
          // 대부분은 가운데 띠만 잘라 빠르게, 3번에 1번은 화면 전체
          var full = frame % 3 === 0;
          var cw = full ? vw : Math.round(vw * 0.9);
          var ch = full ? vh : Math.round(vh * (vh > vw ? 0.35 : 0.6));
          var sx = Math.round((vw - cw) / 2), sy = Math.round((vh - ch) / 2);
          canvas.width = cw; canvas.height = ch;
          ctx.drawImage(v, sx, sy, cw, ch, 0, 0, cw, ch);
          try {
            var texts = await read(ctx.getImageData(0, 0, cw, ch), { maxNumberOfSymbols: 2 });
            if (stopped) return;
            if (texts.length) ui.last.textContent = '읽힌 값: ' + texts.join(', ');
            var isbn = pickIsbn(texts);
            if (!isbn) {
              // 잡지 바코드: 호수까지 읽히면 바로, 호수가 안 읽히면 2.5초 기다렸다가 본 바코드만
              var press = pickPress(texts);
              if (press && press.indexOf('-') > 0) {
                isbn = press;
              } else if (press) {
                if (!pressSeenAt) pressSeenAt = Date.now();
                ui.last.textContent = '잡지용 바코드예요. 옆의 작은 바코드(호수)까지 화면에 넣어 주세요.';
                if (Date.now() - pressSeenAt > 2500) isbn = press;
              }
            }
            if (isbn) {
              if (navigator.vibrate) navigator.vibrate(60);
              ui.line.style.background = '#4ade80';
              setTimeout(function () { finish(isbn); }, 150);
              return;
            }
          } catch (_) { /* 다음 프레임 */ }
        }
        timer = setTimeout(tick, 100);
      }

      (async function start() {
        try {
          if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            throw new Error('이 브라우저는 카메라를 지원하지 않아요');
          }
          var zx = loadZXing();
          stream = await openCamera();
          if (stopped) { stream.getTracks().forEach(function (t) { t.stop(); }); return; }
          var track = stream.getVideoTracks()[0];
          var caps = track.getCapabilities ? track.getCapabilities() : {};
          var adv = {};
          if (caps.focusMode && caps.focusMode.indexOf('continuous') >= 0) adv.focusMode = 'continuous';
          if (caps.zoom && caps.zoom.max >= 2) adv.zoom = Math.max(caps.zoom.min || 1, 1.5); // 조금 떨어져서 찍어도 크게
          if (Object.keys(adv).length) {
            try { await track.applyConstraints({ advanced: [adv] }); } catch (_) {}
          }
          if (caps.torch) {
            ui.torch.style.display = '';
            ui.torch.onclick = function () {
              torchOn = !torchOn;
              track.applyConstraints({ advanced: [{ torch: torchOn }] }).catch(function () {});
            };
          }
          ui.video.srcObject = stream;
          await ui.video.play();
          await zx;
          tick();
        } catch (e) {
          ui.msg.textContent = '카메라를 열 수 없어요.\n브라우저의 카메라 권한을 확인해 주세요.\n(' + (e && e.message || e) + ')';
        }
      })();
    });
  };
})();
