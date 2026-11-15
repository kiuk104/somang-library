/*
 * 소망 도서관 — 복사한 이미지 붙여넣기 (표지)
 *  - somangPasteImage(): 클립보드에서 그림을 꺼내 600px JPEG(품질 0.8)로 줄여 Uint8Array 로 돌려준다.
 *    그림이 없고 글자(주소)만 있으면 그 글자(string)를 돌려준다. 둘 다 없으면 null.
 *    실패하면 한국어 메시지로 reject.
 * 브라우저가 버튼을 누른 그 순간에만 클립보드를 읽게 해 준다 (아이폰은 '붙여넣기' 말풍선이 뜬다).
 * Dart 쪽: lib/screens/books/cover_picker.dart
 */
(function () {
  'use strict';

  var MAX_W = 600, MAX_H = 900, QUALITY = 0.8;

  /** 그림 Blob → 줄인 JPEG 바이트 */
  async function shrink(blob) {
    var bmp = await createImageBitmap(blob);
    var scale = Math.min(1, MAX_W / bmp.width, MAX_H / bmp.height);
    var w = Math.max(1, Math.round(bmp.width * scale));
    var h = Math.max(1, Math.round(bmp.height * scale));
    var canvas = document.createElement('canvas');
    canvas.width = w; canvas.height = h;
    var ctx = canvas.getContext('2d');
    ctx.fillStyle = '#fff'; // 투명 PNG 는 흰 바탕으로
    ctx.fillRect(0, 0, w, h);
    ctx.drawImage(bmp, 0, 0, w, h);
    if (bmp.close) bmp.close();
    var jpeg = await new Promise(function (resolve) {
      canvas.toBlob(resolve, 'image/jpeg', QUALITY);
    });
    if (!jpeg) throw new Error('그림을 바꾸지 못했어요');
    return new Uint8Array(await jpeg.arrayBuffer());
  }

  window.somangPasteImage = async function () {
    if (!navigator.clipboard) {
      throw new Error('이 브라우저는 붙여넣기를 지원하지 않아요');
    }
    // 1) 그림 (Chrome·Safari·Edge)
    if (navigator.clipboard.read) {
      var items;
      try {
        items = await navigator.clipboard.read();
      } catch (e) {
        // 권한 거부 또는 그림이 아닌 경우 — 글자로 다시 시도
        items = null;
      }
      if (items) {
        for (var i = 0; i < items.length; i++) {
          var types = items[i].types || [];
          for (var k = 0; k < types.length; k++) {
            if (types[k].indexOf('image/') === 0) {
              return shrink(await items[i].getType(types[k]));
            }
          }
        }
        // 그림이 없으면 같은 항목의 글자(주소)
        for (var j = 0; j < items.length; j++) {
          if ((items[j].types || []).indexOf('text/plain') >= 0) {
            var b = await items[j].getType('text/plain');
            var t = (await b.text()).trim();
            if (t) return t;
          }
        }
      }
    }
    // 2) 글자만 (Firefox 등)
    if (navigator.clipboard.readText) {
      try {
        var text = (await navigator.clipboard.readText()).trim();
        if (text) return text;
      } catch (e) {
        throw new Error('클립보드를 읽을 수 없어요. 브라우저의 붙여넣기 권한을 허용해 주세요');
      }
    }
    return null;
  };
})();
