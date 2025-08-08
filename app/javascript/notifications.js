export function showNotification(message, type) {
  const notification = document.createElement('div');
  notification.className = `fixed top-4 right-4 px-6 py-4 rounded-lg text-white z-50 shadow-xl transform transition-all duration-300 ease-out ${
    type === 'success' ? 'bg-green-600 border border-green-500/50' : 'bg-red-600 border border-red-500/50'
  }`;
  notification.innerHTML = message; // allow HTML (e.g., links) in the notification message
  notification.style.transform = 'translateX(100%)';
  document.body.appendChild(notification);

  requestAnimationFrame(() => {
    notification.style.transform = 'translateX(0)';
  });

  setTimeout(() => {
    notification.style.transform = 'translateX(100%)';
    setTimeout(() => {
      notification.remove();
    }, 300);
  }, 4700);
} 