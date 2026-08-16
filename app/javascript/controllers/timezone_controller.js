import { Controller } from "@hotwired/stimulus"

// Populates the hidden timezone field on the auth form (spec.md §3) so it's
// captured once at signup without asking the user.
export default class extends Controller {
  static targets = ["field"]

  connect() {
    this.fieldTarget.value = Intl.DateTimeFormat().resolvedOptions().timeZone
  }
}
