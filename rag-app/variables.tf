variable "location" {
  description = "Region for the RAG app"
  type        = string
  default     = "eastus"
}

# ---- On/off switches for later sessions (declared now, wired up later) ----
# Nothing in Session 15 bills while idle, so none of these are used yet.

variable "enable_registry" {
  description = "Container registry (Basic), for the app image later"
  type        = bool
  default     = false
}

variable "enable_messaging" {
  description = "Service Bus Standard namespace for document ingest, later"
  type        = bool
  default     = false
}

variable "enable_postgres" {
  description = "Optional Postgres comparison. Off unless a session says otherwise"
  type        = bool
  default     = false
}

variable "enable_private_endpoints" {
  description = "Private endpoints into the hub-and-spoke lab. Sessions 28-32"
  type        = bool
  default     = false
}
