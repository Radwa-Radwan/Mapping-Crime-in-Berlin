import re
import time
import requests
from bs4 import BeautifulSoup
import os
import pandas as pd


# send request to save html files ---------------

web_pages = pd.read_excel('./data/polizeimeldung.xlsx')
urls = web_pages['incident url'].tolist()

folder_path = './data/html_files'

downloaded_urls = []
failed_urls = []

def get_file_name(url):
    filename = re.sub(r'[<>:"/\\|?*]', '_', url)
    return filename

for url in urls: # subset urls[]
    try:
        response = requests.get(url, timeout=10)

        if response.status_code == 200:
            file_name = get_file_name(url)
            file_path = os.path.join(folder_path, file_name)

            with open(file_path, "w", encoding='utf-8') as file:
                file.write(response.text)

            downloaded_urls.append(url)
        else:
            failed_urls.append(url)

    except requests.exceptions.RequestException as e:
        failed_urls.append(url)

    time.sleep(7) # set time intervals between requests
    print('waited 7 seconds')



df_downloaded = pd.DataFrame({"downloaded" : downloaded_urls})
df_failed = pd.DataFrame({"failed" : failed_urls})
df_downloaded.to_excel('./df_downloaded.xlsx', index=False)
df_failed.to_excel('./df_failed.xlsx', index=False)



# html file scraping ------------------

po_title = []
po_location = []
po_date = []
po_text = []

for filename in os.listdir(folder_path):
    file_path = os.path.join(folder_path, filename)

    with open(file_path, 'r', encoding='utf-8') as file:
        file_content = file.read()

    soup = BeautifulSoup(file_content, 'html.parser')


    title_here = soup.select_one('h1.title').get_text()
    po_title.append(title_here)
    datee = soup.select_one('p.polizeimeldung:nth-child(2)').get_text() # CSS selector
    po_date.append(datee)
    place = soup.select_one('p.polizeimeldung:nth-child(3)').get_text()
    po_location.append(place)
    pargraph = soup.select_one('div.textile p').get_text()
    po_text.append(pargraph)


po_df = pd.DataFrame({'title' : po_title, 'date' : po_date, 'location' : po_location, 'text' : po_text})
po_df.to_excel("./data/police_crime_reports_2024.xlsx", index=False)