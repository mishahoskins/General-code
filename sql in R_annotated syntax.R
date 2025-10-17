
#Running SQL in R

  #Step 1: Install and load the following packages:
                    install.packages("sqldf")

library(sqldf)
library(dplyr)
library(readxl)
                    
  #Step 2: Bring in data
test_data <- read_excel("C:/Users/mhoskins1/Desktop/Work Files/R Codes/test_data.xlsx")


  #Step 3: rename variables where applicable (single word variables are easier for SQL to manage)
test_data2 <- test_data |> 
  rename(age_group = 'Age Group')


  #Step 3: This line starts your SQL much like "proc sql; create table new_table as" follow it with SELECT and your table syntax
  #        end by closing quotes and parenthesis.


                              #Example 1: Total counts by age group
new_table <- sqldf(" 

select 
    age_group, 
    sum(count) as sum_agegroup 

from test_data2 
  group by age_group") 
  
  

                              #Example 2: Total counts by year
new_table2 <- sqldf(" 
select
    year, 
    sum(count) as year_agg

from test_data2
  group by year")




