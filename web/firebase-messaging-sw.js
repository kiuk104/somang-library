// 소망 도서관 웹 푸시 — 앱이 닫혀 있을 때 알림을 띄운다 (firebase_messaging 이 자동 등록)
// 알림 내용·클릭 링크는 서버(loanAction 함수)의 notification / webpush.fcmOptions.link 로 정해진다.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyA-jHS0iL2qw6OeA1zAIzUFq31ZGbmV-Zw',
  appId: '1:351903616224:web:d44fb504d0f0dde6f7d485',
  messagingSenderId: '351903616224',
  projectId: 'mustard-seed-6b9e7',
  authDomain: 'mustard-seed-6b9e7.firebaseapp.com',
  storageBucket: 'mustard-seed-6b9e7.firebasestorage.app',
});

firebase.messaging();
