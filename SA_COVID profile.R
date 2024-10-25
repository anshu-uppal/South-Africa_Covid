# for the first time, use install.packages() to install each of the below packages, then you can run the lines below
library(tidyverse)
library(lubridate)
library(ggrepel)
library(readxl)
library(httr)
library(plotly)
library(scales)

# Deaths data from https://www.samrc.ac.za/reports/report-weekly-deaths-south-africa
# This url should be replaced to get the latest data from the website on deaths
url1 <- 'https://www.samrc.ac.za/sites/default/files/files/2022-01-05/Estimated%20deaths%20for%20SA%2003%20Jan%202022%20with%20adj2.xlsx'
GET(url1, write_disk(tf <- tempfile(fileext = ".xlsx")))
total_deaths <- tibble(read_xlsx(tf, sheet = 2, skip = 1)) %>% 
        select(-...1) %>% rename(Date = ...2, Deaths = `ALL CAUSE`) %>% drop_na(Date) %>%
        mutate(Date = ymd(Date),
               Year = as.character(year(Date)),
               Week = as.numeric(epiweek(Date)),
               Deaths = round(Deaths)) %>%
        select(-c(NATURAL, UNNATURAL)) %>% # no need to keep these as we want "All cause"
        relocate(c(Year, Deaths), .after = Week) %>%
        filter(Date > ymd("2020-02-28"),
               Date < ymd("2021-12-20"))

mdate <- ymd(max(total_deaths$Date)) # generate a value for the latest date in the deaths data

# Data comes from Our World in Data (very comprehensive dataset - no need to update this link): https://ourworldindata.org/coronavirus/country/south-africa
url2 <- "https://covid.ourworldindata.org/data/owid-covid-data.csv"
GET(url2, write_disk(tf2 <- tempfile(fileext = ".csv")))
cases <- read_csv(tf2) %>%
        # read_csv("owid-covid-data.csv") %>%
        mutate(Date = ymd(date),
               Week = epiweek(Date)) %>%
        # select(Date, Week, location, new_cases, new_cases_smoothed) %>%
        filter(location == "South Africa"
               , Date <= mdate # only if we want the cases date limits to be the same as the deaths date limits
        )

# Alert Levels dates manually compiled from https://www.gov.za/covid-19/about/about-alert-system
alert <- read_csv("Alert Levels.csv") %>% 
        mutate(
                Alert_Level = as.character(Alert_Level),
                Start_Date = dmy(Start_Date),
                # Start_Date = as.POSIXct(Start_Date),
                End_Date = dmy(End_Date),
                # End_Date = as.POSIXct(End_Date),
                End_Date = if_else(is.na(End_Date), max(cases$Date), End_Date)
        )


# Graph showing weekly deaths and daily cases (smoothed)
ggplot()+
        geom_rect(data = alert, aes(xmin = Start_Date, xmax = End_Date, # alert level shadings
                                    ymin = -Inf, 
                                    ymax = Inf,
                                    # ymin = min(total_deaths$Deaths)-100, 
                                    # ymax = max(total_deaths$Deaths)+100,
                                    fill = Alert_Level
        ), # geom_rect plotted first so that it goes begind the trend lines
        alpha = 0.4)+
        geom_path(data = total_deaths, aes(x = Date, y = Deaths, color = "blue"), size = 1)+ # not sure why colors get inverted for cases and deaths
        geom_point(data = total_deaths, aes(x = Date, y = Deaths), color = "red", size = 1)+
        geom_path(data = cases, aes(x=Date, y = new_cases_smoothed, color = "red"), size = 1)+
        scale_color_manual(labels = c("Weekly deaths", "Daily cases"), values = c("red", "blue"))+
        scale_fill_manual('Alert Level', # manually choose the colors for the alert level shades
                          values = c("#D4E157", "#FFEE58", 
                                     "#FFCA28", "#F57C00", "#B71C1C"))+
        labs(title = "Weekly deaths (all-cause) and daily COVID-19 cases (7-day smoothed)", color = "")+
        theme_bw()+
        scale_x_date(date_breaks = "2 months", date_labels = "%b-%Y", minor_breaks = NULL)+
        scale_y_continuous(labels = scales::comma, minor_breaks = NULL)+
        theme(axis.title.y = element_blank(),
              axis.title.x = element_blank(),
              legend.key=element_blank()
              # , legend.position = "none"
              , legend.position = c(0.08,0.77) # can play around with these to get a good legend positioning
              , legend.background = element_rect(fill = NA, size = 0)
              , axis.text.x = element_text(angle = 30 , vjust = 0.7, size = 13)
              , panel.grid.major.x = element_blank()
              , panel.grid.minor.x = element_blank()
        )+
        guides(fill = guide_legend(override.aes = list(linetype = 0))) # get rid of lines in legend squares
