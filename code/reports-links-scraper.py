import selenium
import pandas as pd
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.firefox.options import Options
import time
from selenium.webdriver.support import expected_conditions as EC



# generate 2021;2022;2023;2024 pages url from one copied base url

def generate_urls(year,page_numbers):
    url_generated_list = []
    for num in range(1, page_numbers +1): # num to be inserted based on last page no. per year
        url = f"https://www.berlin.de/polizei/polizeimeldungen/archiv/{year}/?page_at_1_0={num}#headline_1_0"
        url_generated_list.append(url)
    return url_generated_list

pages_url_2021 = generate_urls(2021, 51)
pages_url_2022 = generate_urls(2022,45)
pages_url_2023 = generate_urls(2023,45)
pages_url_2024 = generate_urls(2024, 48)


# scraping incidents -------------------------------------

vorfall_url=[]
vorfall=[]
ort=[]
datum=[]

options = Options()
options.add_argument("user-agent= Firefox/136.0; Windows 10; Masterarbeit; contact: {insert email here})") # identifier, ignored!

for link in pages_url_2024: # replace with target year
    driver = webdriver.Firefox(options=options)
    driver.get(link)
    driver.maximize_window()
    time.sleep(1) # better replaced with selenium implicit wait

    try: # find page elements
        incident_url = driver.find_elements(By.CSS_SELECTOR,
                                                'html body#top.locale_de div#page-wrapper.kiekma.screendefault div#layout-grid.template-land_overview div#layout-grid__area--maincontent section.modul-autoteaser ul.list--tablelist li div.cell.text a')

        for retrieved_incident_url in incident_url:
            vorfall_url.append(retrieved_incident_url.get_attribute('href'))

    except NoSuchElementException:
        continue

    # retrive incident title
    try:
        incident_title = driver.find_elements(By.CSS_SELECTOR,
                                                'html body#top.locale_de div#page-wrapper.kiekma.screendefault div#layout-grid.template-land_overview div#layout-grid__area--maincontent section.modul-autoteaser ul.list--tablelist li div.cell.text a')

        for retrieved_incident_title in incident_title:
            vorfall.append(retrieved_incident_title.text)

    except NoSuchElementException:
        continue

    # retrive incident date
    try:
        incident_date = driver.find_elements(By.CSS_SELECTOR,
                                                'html body#top.locale_de div#page-wrapper.kiekma.screendefault div#layout-grid.template-land_overview div#layout-grid__area--maincontent section.modul-autoteaser ul.list--tablelist li div.cell.nowrap.date')

        for retrieved_incident_date in incident_date:
            datum.append(retrieved_incident_date.text)

    except NoSuchElementException:
        continue

    # retrive incident location
    try:
        incident_location = driver.find_elements(By.CSS_SELECTOR, 'html body#top.locale_de div#page-wrapper.kiekma.screendefault div#layout-grid.template-land_overview div#layout-grid__area--maincontent section.modul-autoteaser ul.list--tablelist li div.cell.text')

        for retrieved_incident_location in incident_location:
            ort.append(retrieved_incident_location.text)

    except NoSuchElementException:
        continue

    driver.quit()
    time.sleep(4) # set time intervals


df_incidents_berlin = pd.DataFrame({'incident title': vorfall, 'incident date': datum, 'incident url': vorfall_url, 'incident location': ort})
df_incidents_berlin.to_excel("./data/polizeimeldung.xlsx", index=False)
print("done")
