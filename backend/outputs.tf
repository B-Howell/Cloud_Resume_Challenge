output "invoke_url" {
  description = "the url that will go in the script file so your resume can access the backend"
  value = aws_api_gateway_stage.stage.invoke_url
}