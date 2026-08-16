import { Controller } from "@hotwired/stimulus"

// Live "X / 5,000" counter under the entry textarea, matching Entry's
// server-side length: { maximum: 5000 } validation (app/models/entry.rb).
export default class extends Controller {
  static targets = ["input", "count"]

  static values = {
    max: { type: Number, default: 5000 },
    warnAt: { type: Number, default: 4500 },
  }

  connect() {
    this.update()
  }

  update() {
    const length = this.inputTarget.value.length

    this.countTarget.textContent = `${length.toLocaleString("en-US")} / ${this.maxValue.toLocaleString("en-US")}`
    this.countTarget.classList.toggle("text-amber-600", length >= this.warnAtValue)
    this.countTarget.classList.toggle("text-muted", length < this.warnAtValue)
  }
}
