import 'dart:convert';
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

  const BookInfo({
    required this.title,
    this.author = '',
    this.publisher = '',
    this.isbn = '',
    this.coverUrl = '',
    this.year = '',
  });
}

/// ISBN·제목으로 책 정보 찾기
/// 1) 카카오 책 검색 (한국 책 — 저자·역자·출판사가 한글로). Cloud Function lookupBook 경유
/// 2) Google Books (독일·영어 책 등)
/// 3) ISBN 인데 못 찾으면 Open Library
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
    final isbn = cleanIsbn(q);
    if (isbn != null) {
      final kakao = await _kakao(isbn);
      if (kakao.isNotEmpty) return kakao;
      final google = await _google('isbn:$isbn');
      if (google.isNotEmpty) return google;
      final open = await _openLibrary(isbn);
      return open == null ? const [] : [open];
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
  static Future<List<BookInfo>> _kakao(String q) async {
    try {
      final res = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('lookupBook')
          .call({'query': q})
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
        );
      }).where((b) => b.title.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
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
