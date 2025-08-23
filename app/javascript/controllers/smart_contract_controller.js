import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]
  
  connect() {
    // Controller is already connected via data-controller attribute
    console.log('Smart Contract controller connected')
  }

  toggleSummary(event) {
    event.preventDefault()
    const address = event.currentTarget.dataset.smartContractAddress
    const contractContainer = document.getElementById(`smart_contract_${address}`)
    
    if (!contractContainer) return
    
    // Show loading state
    this.showLoading(contractContainer)
    
    // Fetch summary via Turbo
    fetch(`/app/ethereum/smart_contracts/summary?address_hash=${address}`, {
      method: 'GET',
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      contractContainer.outerHTML = html
      // Re-initialize Stimulus controllers on the new content
      const newElement = document.getElementById(`smart_contract_summary_${address}`)
      if (newElement && this.application) {
        this.application.start()
      }
    })
    .catch(error => {
      console.error('Error fetching summary:', error)
      this.hideLoading(contractContainer)
    })
  }

  toggleDetail(event) {
    event.preventDefault()
    const address = event.currentTarget.dataset.smartContractAddress
    const summaryContainer = document.getElementById(`smart_contract_summary_${address}`)
    
    if (!summaryContainer) return
    
    // Show loading state
    this.showLoading(summaryContainer)
    
    // Fetch detail view via Turbo
    fetch(`/app/ethereum/smart_contracts/detail?address_hash=${address}`, {
      method: 'GET',
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      summaryContainer.outerHTML = html
      // Re-initialize Stimulus controllers on the new content
      const newElement = document.getElementById(`smart_contract_${address}`)
      if (newElement && this.application) {
        this.application.start()
      }
    })
    .catch(error => {
      console.error('Error fetching detail:', error)
      this.hideLoading(summaryContainer)
    })
  }

  showLoading(container) {
    const button = container.querySelector('button[data-action*="toggleSummary"], button[data-action*="toggleDetail"]')
    if (button) {
      button.disabled = true
      button.innerHTML = `
        <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
        Loading...
      `
    }
  }

  hideLoading(container) {
    const button = container.querySelector('button[data-action*="toggleSummary"], button[data-action*="toggleDetail"]')
    if (button) {
      button.disabled = false
      // Restore original button content based on current view
      if (button.dataset.action.includes('toggleSummary')) {
        button.innerHTML = `
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"></path>
          </svg>
          AI Summary
        `
      } else {
        button.innerHTML = `
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
          </svg>
          View Details
        `
      }
    }
  }
}