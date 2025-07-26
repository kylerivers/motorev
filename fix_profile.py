import re

with open('MotoRev/Views/ProfileView.swift', 'r') as f:
    content = f.read()

# Fix the specific problematic line
content = content.replace(
    'receiveCompletion: { [weak self] (completion: Subscribers.Completion<e>) in',
    'receiveCompletion: { [weak self] completion in'
)

content = content.replace(
    'receiveValue: { [weak self] (response: UpdateProfileResponse) in',
    'receiveValue: { [weak self] response in'
)

with open('MotoRev/Views/ProfileView.swift', 'w') as f:
    f.write(content)

print("Fixed ProfileView.swift compilation errors")
