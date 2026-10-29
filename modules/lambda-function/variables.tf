variable "function_name" {
  description = "Lambda function name, e.g. feedback-ingestion"
  type        = string
}

variable "description" {
  description = "Short description of what the function does"
  type        = string
  default     = ""
}

variable "handler" {
  description = "Fully qualified handler, e.g. com.feedback.ingestion.Handler::handleRequest"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "java21"
}

variable "memory_size" {
  description = "Memory in MB; keep the lowest value that performs well, since cost scales with it"
  type        = number
  default     = 512
}

variable "timeout" {
  description = "Timeout in seconds"
  type        = number
  default     = 10
}

variable "environment_variables" {
  description = "Environment variables for the function"
  type        = map(string)
  default     = {}
}
