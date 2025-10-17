



library(pacman)
library(odbc)
library(DBI)
library(dplyr)

#pload(odbc, DBI, dplyr)
#Check drivers shows a list of your drivers
sort(unique(odbcListDrivers() [[1]])) #View drivers

#Connect

con <- dbConnect(odbc(),
                 Driver = "SQL Server",  #Driver name here in double quotes EXACTLY AS IT APPEARS IN YOUR DRIVER MENU. Explore --> ODBC. --> Drivers tab (or view drivers from above)
                 Server = "wv5dphcdcodb02p\\pool", #Server name with a double backslash
                 Database = "DD_Reports", #Database name
                 Trusted_Connection = "Yes", #Trusted connection is usually yes if you're on site or using VPN
) 

#Now you can create an 'object' to use traditional R coding with

vpd_colname_test <- tbl(con,"DD_CLINIC_OUTCOMES_VPD")
colnames(vpd_colname_test)

