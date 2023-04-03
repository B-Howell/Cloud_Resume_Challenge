import json
from unittest.mock import patch
from count import lambda_handler

@patch('boto3.resource')
def test_lambda_handler(mock_table):
    mock_table.return_value.get_item.return_value = {'Item': {'count': 0}}

    # Test GET method
    response = lambda_handler({'httpMethod': 'GET'}, {})
    assert response['statusCode'] == 200

    # Test POST method
    response = lambda_handler({'httpMethod': 'POST'}, {})
    assert response['statusCode'] == 200
