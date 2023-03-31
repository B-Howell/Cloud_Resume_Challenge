import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('visitor_count')

def lambda_handler(event, context):
    http_method = event['httpMethod']

    if http_method == 'POST':
        response = table.get_item(Key={'id':'0'})
        count = response['Item']['count']
        count = count + 1
        print(count)
        response = table.put_item(Item={'id':'0', 'count': count})

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
            },
            "body": json.dumps({
                "message": f"New view count: {count}"
            })
        }
    elif http_method == 'GET':
        response = table.get_item(Key={'id':'0'})
        count = response['Item']['count']
    
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
                "Access-Control-Allow-Methods": "OPTIONS,GET",
                "Content-Type": "application/json"
            },
            "body": json.dumps({"count": str(count)})
        }
    else:
        return {
            "statusCode": 405,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
            },
            "body": json.dumps({"error": "Method not allowed"})
        }