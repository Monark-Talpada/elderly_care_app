importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyAkwW8eKLiqRrHeywhnZqu_nOOl42VZVY8",
  authDomain: "elderlycareapp-35250.firebaseapp.com",
  projectId: "elderlycareapp-35250",
  storageBucket: "elderlycareapp-35250.firebasestorage.app",
  messagingSenderId: "1001240832274",
  appId: "1:1001240832274:web:4f01f16828a9a6fb35ebcb"
});

const messaging = firebase.messaging();

// Optional background message handler
messaging.onBackgroundMessage((payload) => {
  console.log('Background message received:', payload);
  
  // You can customize your background message handling here
  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
    icon: '/favicon.ico'
  });
});