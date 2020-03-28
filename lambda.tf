provider "aws" {

  region="us-west-2"
  
}


 resource "aws_lambda_function" "example" {
   function_name = "hello_world"

   # The bucket name as created earlier with "aws s3api create-bucket"
   s3_bucket = "ibm-odm-dependencies"
   s3_key    = "greetings-0.0.1-SNAPSHOT-shaded.jar"
   # "main" is the filename within the zip file (main.js) and "handler"
   # is the name of the property under which the handler function was
   # exported in that file.
   handler = "com.sb.greetings.SimpleDecisionEngineRunner::handleRequest"
   runtime = "java8"
   timeout="10"
   role = "${aws_iam_role.lambda_exec.arn}"
 }

 # IAM role which dictates what other AWS services the Lambda function
 # may access.
 resource "aws_iam_role" "lambda_exec"{
   name = "hello_world_lambda"

   assume_role_policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
     {
       "Action": "sts:AssumeRole",
       "Principal": {
         "Service": "lambda.amazonaws.com"
       },
       "Effect": "Allow",
       "Sid": ""
     }
   ]
 }
 EOF
 }
 resource "aws_api_gateway_resource" "proxy" {
   rest_api_id = "${aws_api_gateway_rest_api.example.id}"
   parent_id   = "${aws_api_gateway_rest_api.example.root_resource_id}"
   path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
   rest_api_id   = "${aws_api_gateway_rest_api.example.id}"
   resource_id   = "${aws_api_gateway_resource.proxy.id}"
   http_method   = "ANY"
   authorization = "NONE"
 }

 resource "aws_api_gateway_integration" "lambda" {
   rest_api_id = "${aws_api_gateway_rest_api.example.id}"
   resource_id = "${aws_api_gateway_method.proxy.resource_id}"
   http_method = "${aws_api_gateway_method.proxy.http_method}"

   integration_http_method = "POST"
   type                    = "AWS"
   uri                     = "${aws_lambda_function.example.invoke_arn}"
 }

 resource "aws_api_gateway_method" "proxy_root" {
   rest_api_id   = "${aws_api_gateway_rest_api.example.id}"
   resource_id   = "${aws_api_gateway_rest_api.example.root_resource_id}"
   http_method   = "ANY"
   authorization = "NONE"
 }

 resource "aws_api_gateway_integration" "lambda_root" {
   rest_api_id = "${aws_api_gateway_rest_api.example.id}"
   resource_id = "${aws_api_gateway_method.proxy_root.resource_id}"
   http_method = "${aws_api_gateway_method.proxy_root.http_method}"

   integration_http_method = "POST"
   type                    = "AWS"
   uri                     = "${aws_lambda_function.example.invoke_arn}"
 }


resource "aws_api_gateway_method_response" "root_response_200" {
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  resource_id = "${aws_api_gateway_method.proxy_root.resource_id}"
  http_method = "${aws_api_gateway_method.proxy_root.http_method}"
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "proxy_root" {
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  resource_id = "${aws_api_gateway_method.proxy_root.resource_id}"
  http_method = "${aws_api_gateway_method.proxy_root.http_method}"
  status_code = "${aws_api_gateway_method_response.root_response_200.status_code}"
}

resource "aws_api_gateway_method_response" "proxy_response_200" {
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  resource_id = "${aws_api_gateway_method.proxy.resource_id}"
  http_method = "${aws_api_gateway_method.proxy.http_method}"
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "proxy" {
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  resource_id = "${aws_api_gateway_method.proxy.resource_id}"
  http_method = "${aws_api_gateway_method.proxy.http_method}"
  status_code = "${aws_api_gateway_method_response.proxy_response_200.status_code}"

}


 resource "aws_lambda_permission" "apigw" {
   statement_id  = "AllowAPIGatewayInvoke"
   action        = "lambda:InvokeFunction"
   function_name = "${aws_lambda_function.example.function_name}"
   principal     = "apigateway.amazonaws.com"
   # The "/*/*" portion grants access from any method on any resource
   # within the API Gateway REST API.
   source_arn = "${aws_api_gateway_rest_api.example.execution_arn}/*/*"
 }

 resource "aws_api_gateway_deployment" "example" {
   depends_on = [
     aws_api_gateway_integration.lambda,
     aws_api_gateway_integration.lambda_root,
     aws_api_gateway_integration_response.proxy,
     aws_api_gateway_integration_response.proxy_root
   ]

   rest_api_id = "${aws_api_gateway_rest_api.example.id}"
   stage_name  = "test"
 }


