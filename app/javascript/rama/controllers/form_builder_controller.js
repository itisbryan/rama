// Form Builder Stimulus Controller for Visual Builder
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["canvas", "palette", "preview"]
  static values = { 
    config: Object,
    resourceId: String,
    collaborationEnabled: Boolean 
  }

  connect() {
    this.initializeDragDrop()
    this.initializeSortable()
    this.initializeCollaboration()
    this.loadConfiguration()
  }

  initializeDragDrop() {
    // Initialize drag and drop for field palette
    this.paletteTarget.addEventListener('dragstart', this.handleDragStart.bind(this))
    this.canvasTarget.addEventListener('dragover', this.handleDragOver.bind(this))
    this.canvasTarget.addEventListener('drop', this.handleDrop.bind(this))
  }

  initializeSortable() {
    // Initialize sortable for reordering fields
    this.sortable = Sortable.create(this.canvasTarget, {
      animation: 150,
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      dragClass: 'sortable-drag',
      onEnd: this.handleReorder.bind(this)
    })
  }

  initializeCollaboration() {
    if (!this.collaborationEnabledValue) return

    // Connect to collaboration channel
    this.collaborationChannel = this.application.consumer.subscriptions.create(
      {
        channel: "FlexAdmin::CollaborationChannel",
        resource_id: this.resourceIdValue
      },
      {
        received: this.handleCollaborationUpdate.bind(this),
        connected: this.handleCollaborationConnected.bind(this),
        disconnected: this.handleCollaborationDisconnected.bind(this)
      }
    )
  }

  handleDragStart(event) {
    const fieldType = event.target.dataset.fieldType
    event.dataTransfer.setData('field-type', fieldType)
    event.dataTransfer.effectAllowed = 'copy'
  }

  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'copy'
  }

  handleDrop(event) {
    event.preventDefault()
    const fieldType = event.dataTransfer.getData('field-type')
    this.addField(fieldType)
  }

  addField(fieldType) {
    const fieldData = {
      field_type: fieldType,
      name: `field_${Date.now()}`,
      position: this.canvasTarget.children.length
    }

    fetch('/admin/builder/forms/fields', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      },
      body: JSON.stringify({ field: fieldData })
    })
    .then(response => response.text())
    .then(html => {
      // Turbo will handle the response
      this.updatePreview()
      this.broadcastChange('field_added', fieldData)
    })
  }

  handleReorder(event) {
    const fieldId = event.item.dataset.fieldId
    const newPosition = event.newIndex

    fetch(`/admin/builder/forms/fields/${fieldId}/move`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      },
      body: JSON.stringify({ position: newPosition })
    })
    .then(() => {
      this.updatePreview()
      this.broadcastChange('field_moved', { field_id: fieldId, position: newPosition })
    })
  }

  updatePreview() {
    if (!this.hasPreviewTarget) return

    fetch(`/admin/builder/forms/${this.resourceIdValue}/preview`)
      .then(response => response.text())
      .then(html => {
        this.previewTarget.innerHTML = html
      })
  }

  broadcastChange(action, data) {
    if (!this.collaborationEnabledValue) return

    this.collaborationChannel.perform('broadcast_change', {
      action: action,
      data: data,
      user_id: this.currentUserId
    })
  }

  handleCollaborationUpdate(data) {
    if (data.user_id === this.currentUserId) return

    switch (data.action) {
      case 'field_added':
        this.handleRemoteFieldAdded(data.data)
        break
      case 'field_moved':
        this.handleRemoteFieldMoved(data.data)
        break
      case 'field_updated':
        this.handleRemoteFieldUpdated(data.data)
        break
    }
  }

  handleRemoteFieldAdded(fieldData) {
    // Refresh the canvas to show the new field
    this.refreshCanvas()
  }

  handleRemoteFieldMoved(data) {
    // Update field positions without full refresh
    const field = this.canvasTarget.querySelector(`[data-field-id="${data.field_id}"]`)
    if (field) {
      // Move the field to the new position
      const targetPosition = data.position
      const children = Array.from(this.canvasTarget.children)
      if (targetPosition < children.length) {
        this.canvasTarget.insertBefore(field, children[targetPosition])
      } else {
        this.canvasTarget.appendChild(field)
      }
    }
  }

  refreshCanvas() {
    fetch(`/admin/builder/forms/${this.resourceIdValue}`)
      .then(response => response.text())
      .then(html => {
        // Update only the canvas part
        const parser = new DOMParser()
        const doc = parser.parseFromString(html, 'text/html')
        const newCanvas = doc.querySelector('[data-form-builder-target="canvas"]')
        if (newCanvas) {
          this.canvasTarget.innerHTML = newCanvas.innerHTML
        }
      })
  }

  get csrfToken() {
    return document.querySelector('[name="csrf-token"]').content
  }

  get currentUserId() {
    return document.body.dataset.currentUserId
  }
}
