import requests

# Put your API url here
API = ""

# 1. List tasks; must return []
print("1. List tasks (empty)")
r = requests.get(API)
print(r.json())

# 2. Create first task
print("\n2. Create task: Learn Terraform")
r = requests.post(API, json={"title": "Learn Terraform"})
print(r.json())
task_id = r.json()["id"]

# 3. Create a second task
print("\n3. Create task: Deploy to AWS")
r = requests.post(API, json={"title": "Deploy on AWS"})
print(r.json())

# 4. List tasks; both should appear
print("\n4. List tasks (there should be 2)")
r = requests.get(API)
print(r.json())

# 5. Delete the first task
print(f"\n5. Delete task by ID: {task_id}")
r = requests.delete(f"{API}/{task_id}")
print(r.json())

# 6. List again; there should only be one left
print("\n6. List tasks (there should be 1 left)")
r = requests.get(API)
print(r.json())
