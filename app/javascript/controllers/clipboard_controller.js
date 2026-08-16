import { Controller } from "@hotwired/stimulus"

// Copies the pre-written share text (app/helpers/application_helper.rb#share_message)
// so it can be pasted into WhatsApp, email, or SMS.
export default class extends Controller {
  static targets = ["source", "button"]

  async copy() {
    await navigator.clipboard.writeText(this.sourceTarget.textContent.trim())

    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = "Copied!"
    setTimeout(() => { this.buttonTarget.textContent = original }, 2000)
  }
}
