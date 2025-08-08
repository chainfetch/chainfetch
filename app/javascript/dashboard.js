// console.log('Dashboard JavaScript loaded!');

// Make functions globally available for onclick handlers
window.copyToClipboard = copyToClipboard;
window.regenerateApiKey = regenerateApiKey;

function copyToClipboard(text) {
  navigator.clipboard.writeText(text);
  const button = document.getElementById('copyButton');
  button.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-5 h-5"><polyline points="20 6 9 17 4 12"></polyline></svg>`;
  setTimeout(() => {
    button.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-5 h-5"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"></rect><path d="M4 16c-1.1 0-2-.9-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"></path></svg>`;
  }, 2000);
}

function regenerateApiKey() {
  if (!confirm('Are you sure you want to regenerate your API key? Your current API key will stop working immediately.')) {
    return;
  }

  const button = document.getElementById('regenerateButton');
  const originalHTML = button.innerHTML;
  
  // Show loading state
  button.innerHTML = `
    <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
    Regenerating...
  `;
  button.disabled = true;

  fetch('/app/regenerate_api_key', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    }
  })
  .then(response => response.json())
  .then(data => {
    if (data.api_token) {
      document.getElementById('apiToken').textContent = data.api_token;
      document.getElementById('copyButton').setAttribute('onclick', `copyToClipboard('${data.api_token}')`);
    }
  })
  .catch(error => {
    // console.error('Error:', error);
  })
  .finally(() => {
    button.innerHTML = originalHTML;
    button.disabled = false;
  });
}

// Initialize dashboard functionality
document.addEventListener('turbo:load', function() {
  // console.log('Turbo loaded and parsed.');
  
  // Add smooth scroll behavior and fade-in animations
  const cards = document.querySelectorAll('.animate-card');
  cards.forEach((card, index) => {
    card.style.opacity = '0';
    card.style.transform = 'translateY(20px)';
    setTimeout(() => {
      card.style.transition = 'all 0.6s ease-out';
      card.style.opacity = '1';
      card.style.transform = 'translateY(0)';
    }, index * 100);
  });
  
  // Token purchase functionality is now handled by the TokenPurchase class
  // which initializes automatically via its own event listeners
}); 