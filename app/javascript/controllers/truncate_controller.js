import { Controller } from "@hotwired/stimulus"

// Reveals the "Read more" label only when the clamped text actually overflows
// past line-clamp-4 (i.e. the ellipsis is visibly showing). scrollHeight vs
// clientHeight is the only reliable way to detect CSS line-clamp truncation,
// since it depends on rendered width/font, not character count.
export default class extends Controller {
  static targets = ["text", "label"]

  connect() {
    const isTruncated = this.textTarget.scrollHeight > this.textTarget.clientHeight
    this.labelTarget.classList.toggle("hidden", !isTruncated)
  }
}
