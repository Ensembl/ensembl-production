import requests
import argparse

def main(args):
    github_token = args.token
    repository_owner = args.owner
    repo_file_path = args.repo_file
    assignee = args.assignee
    title = args.pr_title
    with open(repo_file_path) as repos :
        for repo in repos :
            repo = repo.rstrip()
            base_url = f"https://api.github.com/repos/{repository_owner}/{repo}/pulls"
            
            print(f'Approving and merging repo {repo}')

            # Get the list of open pull requests assigned to the specified user
            headers = {
                "Authorization": f"Bearer {github_token}",
                "Accept": "application/vnd.github.v3+json"
            }
            response = requests.get(f"{base_url}?state=open&assignee={assignee}", headers=headers)
            assigned_pull_requests = response.json()            

            # Iterate through each assigned pull request, approve, and merge it
            for pr in assigned_pull_requests:
                if pr['title'] != title:
                    print(f"repo {repo} Expected PR title {pr['title']} differs from provided title {title}")
                    continue  
                
                pr_number = pr['number']

                # Approve the pull request
                approve_url = f"{base_url}/{pr_number}/reviews"
                approve_payload = {"event": "APPROVE"}
                approve_response = requests.post(approve_url, json=approve_payload, headers=headers)

                if approve_response.status_code == 200:
                    print(f"Pull request #{pr_number} approved successfully.")
                    
                    # Merge the pull request
                    merge_url = f"{base_url}/{pr_number}/merge"
                    merge_response = requests.put(merge_url, headers=headers)

                    if merge_response.status_code == 200:
                        print(f"Pull request #{pr_number} merged successfully.")
                    else:
                        print(f"Error merging pull request #{pr_number}. Status code: {merge_response.status_code}")
                else:
                    print(f"Error approving pull request #{pr_number}. Status code: {approve_response.status_code}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Automate approval and merging of GitHub pull requests.")
    parser.add_argument("--token", required=True, help="GitHub personal access token")
    parser.add_argument("--owner", required=False, help="GitHub repository owner", default="Ensembl")
    parser.add_argument("--repo_file", required=True, help="GitHub repository name")
    parser.add_argument("--assignee", required=True, help="GitHub username for assigned pull requests")
    parser.add_argument("--pr_title", required=True, help="title for assigned pull request ")
    
    
    args = parser.parse_args()
    main(args)