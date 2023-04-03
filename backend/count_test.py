import json
from unittest.mock import patch
from count import lambda_handler

@patch('boto3.resource')
def test_lambda_handler(mock_resource):
    mock_table = mock_resource().Table()
    mock_table.get_item.return_value = {'Item': {'count': 0}}

    # Test POST method
    response = lambda_handler({'httpMethod': 'POST'}, {})
    assert response['statusCode'] == 200
    assert json.loads(response['body'])['message'] == 'New view count is 1'

    # Test GET method
    mock_table.get_item.return_value = {'Item': {'count': 1}}
    response = lambda_handler({'httpMethod': 'GET'}, {})
    assert response['statusCode'] == 200
    assert json.loads(response['body'])['count'] == '1'

    # Test invalid method
    response = lambda_handler({'httpMethod': 'PUT'}, {})
    assert response['statusCode'] == 405
    assert json.loads(response['body'])['error'] == 'Method not allowed'
