from langchain_core.messages import AIMessage, HumanMessage
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_ollama.llms import OllamaLLM
from langchain_core.output_parsers import PydanticOutputParser
from langchain_community.document_loaders import DataFrameLoader
from typing import Optional
from typing import List
from pydantic import BaseModel, Field
import pandas as pd
import torch
from dask.distributed import Client
from dask_cuda import LocalCUDACluster
import dask
from tqdm import tqdm

cluster = LocalCUDACluster() # parellelize
client = Client(cluster) # set no. of workers optional to not overload the server

df = pd.read_excel("police_crime_reports_2024.xlsx") # merge text and date cols after loading the file


model = OllamaLLM(model="llama3.3",  # 70B
                  temperature=0,  # ensures deterministic behavior
                  top_p=1,  # considers all token options for extraction
                  top_k=1)  # goes through all text tokens


# set up parser
class Crime(BaseModel): # time is not included or tested for parsing
    """The document is a police crime report.
    The document includes the details about the crime category, date and location. """

    crime_name:Optional[str] = Field(default=True, description="crime category")
    crime_location:Optional[str] = Field(default=True, description="crime exact location")
    crime_date:Optional[str] = Field(default=None, description="crime date")


class CrimeList(BaseModel):
    """Identifying information about all crimes in a text."""

    crime: List[Crime]

parser = PydanticOutputParser(pydantic_object=CrimeList)


# test query = [] you can set a test report here


# set up chat template
prompt = ChatPromptTemplate.from_messages(
    [
        (
            "system", "You are an extraction algorithm."
                      "extract requested info from the police report"
                      "Answer the user query. Wrap the output in `json` tags"),
        ("human", "From the following report extract crime category and location based on the following instructions. "
                  "1- Choose only one of the following crime categories to label the crime: Raub, Körperverletzung, Diebstahl, Drogenkriminalität, Beschädigung, Übergriff, Verkehrsdelikte, Brandstiftung."
                  "2- If the crime does not fit any of the categories provided to you, retrun none of these categories. "
                  "3- Return empty json when no clear mention of a specific crime committed by a perpetrator. "
                  "4- Extract a precise main location of the crime. "
                  "5- The precise location extracted must be in geocodable format, without information additions from your side"
                  "6- Locations should not be repeated. "
                  "7- Additional location information that is NOT part of the text is NOT desired. "
                  "8- Extract the crime date in format dd/mm/yyyy "
                  "9- The date mentioned in the document is the reporting date, adjust the date by taking into account words such as for example 'gestern'. "
                  "10- If there is more than one crime mentioned, return json output for every crime. "
                  "11- Extract time in format %H:%M only if the time is explicitly mentioned. "
                  "12 - number of json tags should match the number of individual incidents mentiond in the report"
                  "here is the {report}"),
        ("system", "You return the requested info"),
        ("human",
         "Review the precision of your response to make sure information you extracted is correct against the information in the report. Return the final correct answer saying here is the final answer: json tag format ")
    ]
).partial(format_instructions=parser.get_format_instructions()) # remove parser to inspect the model's CoT

chain = prompt | model  | parser # remove parser here as well

subset_1 = df.iloc[:500] # due to extended runtime, subset[] is preferable
subset_2 = df.iloc[500:1000]
subset_3 = df.iloc[1000:1500]
subset_4 = df.iloc[1500:2000]
subset_5 = df.iloc[2000:]

responses = []
for report in tqdm(subset_{"no"}["text_date"][:]): # replace {no.} with subset file no.
    response = chain.invoke({'report': report})
    responses.append(response)


output_df = pd.DataFrame({
    'title': subset['title'][:],
    'date': subset['date'][:],
    'location': subset['location'][:],
    'text': subset['text'][:],
    'text_date': subset['text_date'][:],
    'results': responses
})
output_df.to_excel('llm-output.xlsx', index=False)
print("done")


torch.cuda.empty_cache()
client.close()
cluster.close()