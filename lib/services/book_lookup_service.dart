import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

/// 책 정보 검색 결과 (등록 폼을 채우는 데 쓴다)
class BookInfo {
  final String title;
  final String author;
  final String publisher;
  final String isbn;
  final String coverUrl;
  final String year;
  // 책 정보 보기용 (검색 목록에서는 비어 있을 수 있다)
  final String description; // 책 소개
  final String date; // 출간일 'YYYY-MM-DD' 또는 'YYYY'
  final int pages;
  final int price; // 정가 (원)
  final String link; // 소개 전문을 볼 수 있는 다음(Daum) 책 페이지 (카카오 결과만)

  const BookInfo({
    required this.title,
    this.author = '',
    this.publisher = '',
    this.isbn = '',
    this.coverUrl = '',
    this.year = '',
    this.description = '',
    this.date = '',
    this.pages = 0,
    this.price = 0,
    this.link = '',
  });
}

/// ISBN·제목으로 책 정보 찾기
/// 1) 카카오 책 검색 (한국 책 — 저자·역자·출판사가 한글로). Cloud Function lookupBook 경유
/// 2) Google Books (독일·영어 책 등)
/// 3) ISBN 인데 못 찾으면 독일 국립도서관(DNB) → lobid(도서관 연합) — 독일어 만화·책. lookupBook(source: dnb) 경유
/// 4) 그래도 없으면 Open Library
/// 5) 다 못 찾으면 우리 도서관에 같은 번호로 등록된 책 (다른 교인이 직접 입력한 정보)
/// ISBN 이 없는 잡지형 책(LTB 등, 419·414·977 바코드)은 우리 도서관에서만 찾는다
class BookLookupService {
  static const _timeout = Duration(seconds: 10);

  /// 숫자(와 끝자리 X)만 남긴 ISBN. 10·13자리가 아니면 null
  static String? cleanIsbn(String raw) {
    final s = raw.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');
    if (s.length == 13 && RegExp(r'^\d{13}$').hasMatch(s)) return s;
    if (s.length == 10 && RegExp(r'^\d{9}[\dX]$').hasMatch(s)) return s;
    return null;
  }

  /// 바코드 스캔 값에서 책 ISBN 찾기
  /// - 978/979 로 시작하는 13자리 (부가기호가 붙어 18자리로 읽혀도 앞 13자리)
  /// - 체크섬이 맞는 것만 인정
  static String? findIsbnInScan(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    for (final m in RegExp(r'97[89]\d{10}').allMatches(digits)) {
      final isbn = m.group(0)!;
      if (_validIsbn13(isbn)) return isbn;
    }
    return null;
  }

  /// ISBN 이 없는 잡지형 책 바코드 (독일 잡지 419·414, ISSN 977)
  /// 옆의 작은 부가 바코드(호수)가 같이 읽히면 '4193889712990-04' 처럼 붙인다. web/scanner.js 와 같은 규칙
  static String? findPressCode(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final m = RegExp(r'^(41[49]\d{10}|977\d{10})(\d{2}|\d{5})?$').firstMatch(digits);
    if (m == null || !_validIsbn13(m.group(1)!)) return null;
    return m.group(2) == null ? m.group(1) : '${m.group(1)}-${m.group(2)}';
  }

  /// 검색어가 잡지 바코드 모양인지 ('4193889712990-04' 또는 13자리)
  static bool isPressCode(String q) => findPressCode(q) != null;

  /// 바코드 스캔 값 → 책 번호 (ISBN 우선, 없으면 잡지 바코드)
  static String? findCodeInScan(String raw) =>
      findIsbnInScan(raw) ?? findPressCode(raw);

  /// 표지만 찾기 — 함수가 여러 표지 서버(독일 서점 연합 MVB, Open Library)를 확인해
  /// 진짜 그림이 있는 주소를 돌려준다. 없으면 빈 문자열
  static Future<String> findCover(String isbn) async {
    final clean = cleanIsbn(isbn);
    if (clean == null) return '';
    try {
      final res = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('lookupBook')
          .call({'query': clean, 'source': 'cover'})
          .timeout(const Duration(seconds: 15));
      return (res.data as Map)['cover']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 우리 도서관에 같은 번호(ISBN·잡지 바코드)로 등록된 책 — 처음 등록한 사람이 입력한 정보를 재사용
  static Future<List<BookInfo>> _library(String code) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('books')
          .where('isbn', isEqualTo: code)
          .limit(5)
          .get()
          .timeout(_timeout);
      final seen = <String>{};
      final list = <BookInfo>[];
      for (final d in snap.docs) {
        final m = d.data();
        final title = m['title']?.toString() ?? '';
        if (title.isEmpty || !seen.add(title)) continue;
        list.add(BookInfo(
          title: title,
          author: m['author']?.toString() ?? '',
          publisher: m['publisher']?.toString() ?? '',
          isbn: code,
          coverUrl: m['coverUrl']?.toString() ?? '',
        ));
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  static bool _validIsbn13(String s) {
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += int.parse(s[i]) * (i.isEven ? 1 : 3);
    }
    return (10 - sum % 10) % 10 == int.parse(s[12]);
  }

  /// 검색어가 ISBN 이면 ISBN 검색, 아니면 제목·저자 검색
  static Future<List<BookInfo>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final press = findPressCode(q);
    if (press != null) return _library(press);
    final isbn = cleanIsbn(q);
    if (isbn != null) {
      final kakao = await _kakao(isbn);
      if (kakao.isNotEmpty) return kakao;
      final google = await _googleIsbn(isbn);
      if (google.isNotEmpty) return google;
      final dnb = await _kakao(isbn, source: 'dnb');
      if (dnb.isNotEmpty) return dnb;
      final open = await _openLibrary(isbn);
      if (open != null) return [open];
      return _library(isbn);
    }
    // 제목 검색: 카카오(한국 책) 결과를 먼저, 그 뒤에 Google 결과 (같은 ISBN 은 빼고)
    final results = await Future.wait([_kakao(q), _google(q)]);
    final kakao = results[0];
    final seen = kakao.map((b) => b.isbn).where((s) => s.isNotEmpty).toSet();
    return [
      ...kakao,
      ...results[1].where((b) => b.isbn.isEmpty || !seen.contains(b.isbn)),
    ];
  }

  /// 카카오 책 검색 — API 키는 서버(함수)에만 있다. 함수가 없거나 실패하면 빈 목록
  /// source: 'dnb' 이면 같은 함수가 독일 국립도서관에서 ISBN 으로 찾는다 (결과 모양은 같다)
  static Future<List<BookInfo>> _kakao(String q, {String? source}) async {
    try {
      final res = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('lookupBook')
          .call({'query': q, if (source != null) 'source': source})
          .timeout(_timeout);
      final data = Map<String, dynamic>.from(res.data as Map);
      final list = (data['books'] as List?) ?? const [];
      return list.whereType<Map>().map((m) {
        List<String> names(dynamic v) =>
            (v as List?)?.map((e) => '$e').where((e) => e.isNotEmpty).toList() ??
            const [];
        final authors = names(m['authors']).join(', ');
        final translators = names(m['translators']);
        return BookInfo(
          title: m['title']?.toString() ?? '',
          author: translators.isEmpty
              ? authors
              : '$authors (${translators.join(', ')} 옮김)',
          publisher: m['publisher']?.toString() ?? '',
          isbn: m['isbn']?.toString() ?? '',
          coverUrl: m['thumbnail']?.toString() ?? '',
          year: m['year']?.toString() ?? '',
          description: m['contents']?.toString() ?? '',
          date: m['date']?.toString() ?? '',
          price: int.tryParse('${m['price'] ?? ''}') ?? 0,
          pages: int.tryParse('${m['pages'] ?? ''}') ?? 0,
          link: m['url']?.toString() ?? '',
        );
      }).where((b) => b.title.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Google Books ISBN 검색 — 'isbn:' 검색에 안 걸리는 책이 숫자만으로는 나올 때가 있어 한 번 더
  static Future<List<BookInfo>> _googleIsbn(String isbn) async {
    final first = await _google('isbn:$isbn');
    if (first.isNotEmpty) return first;
    final plain = await _google(isbn);
    // 숫자 검색은 엉뚱한 책이 섞일 수 있으니 ISBN 이 같은 것만
    final isbn10 = isbn.length == 13 ? _toIsbn10(isbn) : null;
    return plain.where((b) => b.isbn == isbn || b.isbn == isbn10).toList();
  }

  /// 978 로 시작하는 13자리 → 10자리 (979 는 10자리가 없다)
  static String? _toIsbn10(String isbn13) {
    if (!isbn13.startsWith('978')) return null;
    final core = isbn13.substring(3, 12);
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      sum += int.parse(core[i]) * (10 - i);
    }
    final c = (11 - sum % 11) % 11;
    return '$core${c == 10 ? 'X' : '$c'}';
  }

  static Future<List<BookInfo>> _google(String q) async {
    final uri = Uri.https('www.googleapis.com', '/books/v1/volumes', {
      'q': q,
      'maxResults': '15',
      'printType': 'books',
    });
    try {
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (body['items'] as List?) ?? const [];
      return items
          .whereType<Map>()
          .map((item) => _fromGoogle(item['volumeInfo']))
          .whereType<BookInfo>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static BookInfo? _fromGoogle(dynamic raw) {
    if (raw is! Map) return null;
    final title = raw['title']?.toString() ?? '';
    if (title.isEmpty) return null;
    final subtitle = raw['subtitle']?.toString() ?? '';
    final authors = (raw['authors'] as List?)?.map((e) => '$e').join(', ') ?? '';

    var isbn = '';
    for (final id in (raw['industryIdentifiers'] as List?) ?? const []) {
      if (id is Map && id['type'] == 'ISBN_13') isbn = '${id['identifier']}';
      if (id is Map && id['type'] == 'ISBN_10' && isbn.isEmpty) {
        isbn = '${id['identifier']}';
      }
    }

    final links = raw['imageLinks'];
    var cover = links is Map
        ? (links['thumbnail'] ?? links['smallThumbnail'] ?? '').toString()
        : '';
    // http → https, 책 넘김 효과 제거
    cover = cover.replaceFirst('http://', 'https://').replaceAll('&edge=curl', '');

    final date = raw['publishedDate']?.toString() ?? '';
    return BookInfo(
      title: subtitle.isEmpty ? title : '$title : $subtitle',
      author: authors,
      publisher: raw['publisher']?.toString() ?? '',
      isbn: isbn,
      coverUrl: cover,
      year: date.length >= 4 ? date.substring(0, 4) : '',
      description: _stripHtml(raw['description']?.toString() ?? ''),
      date: date,
      pages: int.tryParse('${raw['pageCount'] ?? ''}') ?? 0,
    );
  }

  static String _stripHtml(String s) => s
      .replaceAll(RegExp(r'<br\s*/?>|</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();

  /// 책 정보 보기 — ISBN 이 있으면 ISBN 으로, 없으면 제목·저자로 찾아
  /// 카카오(한국 책: 정가·출간일·소개)와 Google Books(소개·쪽수)를 합친다. 못 찾으면 null
  static Future<BookInfo?> details({
    required String isbn,
    required String title,
    String author = '',
  }) async {
    // 잡지 바코드(LTB 등)는 바깥 데이터베이스에 없으니 제목으로 찾는다
    final clean = isPressCode(isbn) ? null : cleanIsbn(isbn);
    final q = clean ?? '$title $author'.trim();
    if (q.isEmpty) return null;
    final results = await Future.wait([
      _kakao(q),
      clean != null ? _googleIsbn(clean) : _google(q),
    ]);
    var k = results[0].isEmpty ? null : results[0].first;
    final g = results[1].isEmpty ? null : results[1].first;
    // 둘 다 없으면 독일 국립도서관 (독일어 책)
    if (k == null && g == null && clean != null) {
      final dnb = await _kakao(clean, source: 'dnb');
      if (dnb.isNotEmpty) k = dnb.first;
    }
    if (k == null && g == null) return null;
    final base = k ?? g!;
    // 소개는 더 긴 쪽 (카카오는 앞부분만 줘서 짧다)
    final kd = k?.description ?? '', gd = g?.description ?? '';
    return BookInfo(
      title: base.title,
      author: base.author,
      publisher: base.publisher,
      isbn: base.isbn,
      coverUrl: base.coverUrl,
      year: base.year,
      // 카카오 소개는 앞부분만 오므로(약 300자) 잘린 채 끝나면 … 를 붙여 준다
      description: gd.length > kd.length
          ? gd
          : (kd.isNotEmpty && !RegExp(r'[.!?。」』”"\)]$').hasMatch(kd.trim())
              ? '${kd.trim()}…'
              : kd),
      date: (k?.date.isNotEmpty ?? false) ? k!.date : (g?.date ?? ''),
      pages: (g?.pages ?? 0) > 0 ? g!.pages : (k?.pages ?? 0),
      price: k?.price ?? 0,
      link: k?.link ?? '',
    );
  }

  static Future<BookInfo?> _openLibrary(String isbn) async {
    final uri = Uri.https('openlibrary.org', '/api/books', {
      'bibkeys': 'ISBN:$isbn',
      'format': 'json',
      'jscmd': 'data',
    });
    try {
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      final data = body is Map ? body['ISBN:$isbn'] : null;
      if (data is! Map) return null;
      final title = data['title']?.toString() ?? '';
      if (title.isEmpty) return null;
      String names(dynamic list) => (list as List?)
              ?.whereType<Map>()
              .map((e) => '${e['name']}')
              .join(', ') ??
          '';
      final cover = data['cover'] is Map
          ? (data['cover']['medium'] ?? data['cover']['small'] ?? '').toString()
          : '';
      final date = data['publish_date']?.toString() ?? '';
      final year = RegExp(r'\d{4}').firstMatch(date)?.group(0) ?? '';
      return BookInfo(
        title: title,
        author: names(data['authors']),
        publisher: names(data['publishers']),
        isbn: isbn,
        coverUrl: cover.replaceFirst('http://', 'https://'),
        year: year,
      );
    } catch (_) {
      return null;
    }
  }
}
