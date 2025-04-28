import re
import time
import requests
from bs4 import BeautifulSoup
import os
import pandas as pd

folder_path = './BerlinClubs'
file_name = 'clubslinks.html'
full_path = os.path.join(folder_path, file_name)

# Send HTTP GET request
response = requests.get('https://www.berlin.de/clubs-und-party/clubguide/a-z/')

# Save the HTML file to the folder
with open(full_path, 'w', encoding='utf-8') as f:
    f.write(response.text)


with open(full_path, 'r', encoding='utf-8') as f:
    html_content = f.read()

# 5. Parse the HTML with BeautifulSoup
soup = BeautifulSoup(html_content, 'html.parser')



links_list = []
link_elements = soup.find_all('a', class_='nowidows')
links_list = [link.get('href') for link in link_elements if link.get('href')]


df_links = pd.DataFrame(links_list, columns=['Links'])

# Save DataFrame to Excel
df_links.to_excel("./BerlinClubs/clubs_links.xlsx", index=False)



parsed_links = ['https://www.berlin.de' + link  for link in links_list]

def get_file_name(url):
    # Create a simple filename based on the URL
    return url.replace("https://", "").replace("http://", "").replace("/", "_") + ".html"


for url in parsed_links:
    try:
        print(f"Fetching: {url}")
        response = requests.get(url, timeout=10)
        response.raise_for_status()  # Optional: raise error for bad status codes

        file_name = get_file_name(url)
        file_path = os.path.join(folder_path, file_name)

        with open(file_path, "w", encoding='utf-8') as file:
            file.write(response.text)

        print(f"Saved HTML to: {file_path}")

    except requests.exceptions.RequestException as e:
        print(f"Error fetching {url}: {e}")

    time.sleep(7)
    print("link done")


club_location = []
for filename in os.listdir(folder_path):
    file_path = os.path.join(folder_path, filename)

    with open(file_path, 'r', encoding='utf-8') as file:
        file_content = file.read()

    soup = BeautifulSoup(file_content, 'html.parser')

    locations = soup.select('dd > div:nth-of-type(-n+2)')
    for l in locations:
    # locations_text = locations.get_text()
        club_location.append(l.get_text(strip=True))

joined_address = [club_location[i] + " " + club_location[i+1] for i in range(0, len(club_location), 2)]

df_clublocations = pd.DataFrame(joined_address, columns=['club_address'])

# Save DataFrame to Excel
df_clublocations.to_excel("./data/nightclubs_locations.xlsx", index=False)