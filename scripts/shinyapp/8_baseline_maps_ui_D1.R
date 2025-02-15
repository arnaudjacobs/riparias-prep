library(shiny)
library(shinydashboard)
library(leaflet)
library(rgdal)
library(dplyr)
library(ggplot2)
library(sf)
library(stringr)
library(trias) 

#possible cause of failure concerning trias package:
# Only packages installed from GitHub with devtools::install_github, in version 1.4 (or later) of devtools, are supported. Packages installed with an earlier version of devtools must be reinstalled with the later version before you can deploy your application. If you get an error such as “PackageSourceError” when you attempt to deploy, check that you have installed all the packages from Github with devtools 1.4 or later.

#Reading in data####
branch <- "master"

all_pointdata_2000 <- st_read(paste0("https://github.com/inbo/riparias-prep/raw/", 
                                     branch, 
                                     "/data/spatial/baseline/points_in_perimeter_sel.geojson"))

current_state <- readOGR(paste0("https://github.com/inbo/riparias-prep/raw/",
                                branch, 
                                "/data/spatial/baseline/current_state.geojson"),
                         stringsAsFactors = FALSE)

baseline_state <- readOGR(paste0("https://github.com/inbo/riparias-prep/raw/",
                                 branch,
                                 "/data/spatial/baseline/baseline.geojson"),
                          stringsAsFactors = FALSE)

RBU_laag <- readOGR(paste0("https://github.com/inbo/riparias-prep/raw/",
                           branch, 
                           "/data/spatial/Riparias_subunits/RBU_RIPARIAS_12_02_2021.geojson"), 
                    stringsAsFactors = FALSE)

RBSU_laag <- readOGR(paste0("https://github.com/inbo/riparias-prep/raw/",
                            branch,
                            "/data/spatial/Riparias_subunits/RBU_RIPARIAS_12_02_2021.geojson"),
                     stringsAsFactors = FALSE)

EEA_per_species_baseline <- st_as_sf(
              readOGR(paste0("https://github.com/inbo/riparias-prep/raw/",
                             branch,
                             "/data/interim/EEA_per_species_baseline.geojson")))

EEA_per_species_current <- st_as_sf(
              readOGR(paste0("https://github.com/inbo/riparias-prep/raw/",
                             branch,
                             "/data/interim/EEA_per_species_current.geojson")))
EEA_surveillance_effort <- st_as_sf(
                        readOGR(paste0("https://github.com/inbo/riparias-prep/raw/",
                        branch,
                        "/data/interim/EEA_high_search_effort.geojson")))
level_of_invasion_RBSU <- st_as_sf(readOGR(paste0("https://github.com/inbo/riparias-prep/raw/", branch,"/data/interim/level_of_invasion_RBSU.geojson")))

level_of_invasion_RBSU_current <- level_of_invasion_RBSU%>%filter(state=='current')
level_of_invasion_RBSU_baseline <- level_of_invasion_RBSU%>%filter(state=='baseline')

bbox <- as.data.frame(RBU_laag@bbox)

occupancy_RBU <- read.csv(paste0("https://github.com/inbo/riparias-prep/raw/",
                                 branch,
                                 "/data/interim/occupancy_rel_RBU.csv"))

occupancy_RBSU <- read.csv(paste0("https://github.com/inbo/riparias-prep/raw/", 
                                  branch,
                                  "/data/interim/occupancy_rel_RBSU.csv"))%>%
  rename(A0_CODE=RBSU)

Surveillance_effort_RBSU <- read.csv(paste0("https://github.com/inbo/riparias-prep/raw/", 
                                            branch,
                                            "/data/interim/Surveillance_effort.csv"))

full_name_RBSU <- read.csv(paste0("https://github.com/inbo/riparias-prep/raw/",
                                  branch, 
                                  "/data/input/Full_name_per_RBSU.csv"), sep=";")

occupancy_RBSU <- merge(occupancy_RBSU, full_name_RBSU, by.x='A0_CODE', by.y='Id', all.x=TRUE)
Surveillance_effort_RBSU <- merge(Surveillance_effort_RBSU, full_name_RBSU, by= 'Id', all.x=TRUE)
centroid_per_RBSU <- read.csv(paste0("https://github.com/inbo/riparias-prep/raw/",
                                     branch,
                                     "/data/input/centroid_per_RBSU_versie2.csv"))
centroid_per_RBSU <- merge(centroid_per_RBSU, full_name_RBSU, by='Id', all.x=TRUE)

level_of_invasion_RBSU_current <- merge (level_of_invasion_RBSU_current, full_name_RBSU,by= 'Id', all.x=TRUE)
level_of_invasion_RBSU_baseline <- merge(level_of_invasion_RBSU_baseline, full_name_RBSU, by= 'Id', all.x=TRUE)

level_of_invasion_color_current <- as.data.frame(level_of_invasion_RBSU_current)
level_of_invasion_color_baseline <- as.data.frame(level_of_invasion_RBSU_baseline)

df_ts_compact <- read.csv(paste0("https://github.com/inbo/riparias-prep/raw/",
                                 branch,
                                 "/data/interim/trends_compact.csv"))

## Calculate evaluation years ####
evaluation_years <- seq(from = as.integer(format(Sys.Date(), "%Y")) - 4,
                        to = as.integer(format(Sys.Date(), "%Y")) - 1)

maxjaar <- as.integer(format(Sys.Date(), "%Y"))

#Userinterface####

ui <- navbarPage(
  title = "Riparias D1",
  #header= 
  #  fluidRow(
  #  box(width = 12, 
  #    img(src='Riparias_Logo.png', align = "right", height = 90)
  #)
  #),
  ##Distribution####
  tabPanel("Distribution",
    tabsetPanel(
      tabPanel('Maps',
    titlePanel('Maps'),
    sidebarLayout(
      sidebarPanel(
        sliderInput("slider", 
                    "Years", 
                    2000, 
                    lubridate::year(Sys.Date()), 
                    1,
                    value = c(2010, 2020),
                    dragRange = TRUE),
        checkboxGroupInput("species",
                           "Species",
                           choices = unique(all_pointdata_2000$species)
        )
        ),
      mainPanel(
        fluidRow(
          box(width = 12,
            uiOutput("text1"),
            leafletOutput("map", height = 600)
          )
        )
      )
  )
),#tabpanel
##Occupancy####
tabPanel('Occupancy',
         titlePanel('Occupancy'),
         sidebarLayout(
           sidebarPanel(
             selectInput("RBUi", "Select a river basin:",
                         choices = unique(occupancy_RBU$RBU))
           ),
           mainPanel(
             fluidRow(
               tabsetPanel(
                           tabPanel("Absolute occupancy", plotOutput("OccRBU")),
                           tabPanel("Relative occupancy", plotOutput("OccRBUREL"))
               )
             )
           )),
         

         sidebarLayout(
           sidebarPanel(
             selectInput("RBSUi", " Select a river basin subunit:",
                         choices = unique(occupancy_RBSU$fullnameRBSU))
           ),
           mainPanel(
             fluidRow(
               tabsetPanel(type = "tabs",
                           tabPanel("Absolute occupancy", plotOutput("OccRBSU")),
                           tabPanel("Relative occupancy", plotOutput("OccRBSUREL"))
               )
             )
           )),
         box(' '),
         box(' '),
         box("Baseline state for plants: 1/1/2000-31/12/2020"), 
         box("Baseline state for crayfish:1/1/2000 - 31/12/2015"),
         box("Current state for plants: 1/1/2021 - present"),
         box("Current state for crayfish: 1/1/2016 - present")
)#tabPanel

)#tabsetPanel
),#tabPanel
##Surveillance####
tabPanel('Surveillance',
      tabsetPanel(
        tabPanel('Observations',
        titlePanel('Observations'),
        sidebarLayout(

          sidebarPanel(
            selectInput("RBUi2", "Select a river basin:",
                        choices = unique(occupancy_RBU$RBU))
          ),
          mainPanel(
              plotOutput("graphRBU")
            )
          ),
        sidebarLayout(
          
          sidebarPanel(
            selectInput("RBSUi2", "Select a river basin subunit:",
                        choices = unique(occupancy_RBSU$fullnameRBSU))
          ),
          mainPanel(
            fluidRow(
              plotOutput("graphRBSU")
            )
          )
        ),
        box(' '),
        box(' '),
        box("Baseline state for plants: 1/1/2000-31/12/2020"), 
        box("Baseline state for crayfish:1/1/2000 - 31/12/2015"),
        box("Current state for plants: 1/1/2021 - present"),
        box("Current state for crayfish: 1/1/2016 - present")  
        ),#tabPanel,
        tabPanel('Effort',
                 titlePanel('Surveillance effort'),
                 fluidRow(
                   box(
                     'Percentage of EEA cells (1km²) per river basin subunit with heigh surveillance effort for plant species',
                   plotOutput("Plot_surveillance_effort_RBSU", height=600)
                   ),
                   box(
                     'Distribution of EEA cells (1km²) with high surveillance effort for plant species',
                     leafletOutput("map_EEA_surveillance_effort", height=600)
                   )
                   )#fluidrow
        )#tabPanel Effort
                 )#tabsetPanel 
         ),#tabPanel Surveillance
##Species trends####
tabPanel('Species trends',
         titlePanel('Species trends'),
         sidebarLayout(
           sidebarPanel(
             selectInput("Species_trends", "Select a species:",
                         choices = unique(occupancy_RBSU$species))
             ),#sidebarPanel
           mainPanel(
             fluidRow(
               box(
                 title='Observations',
                 plotOutput("plot_trends_obs")
               ),
               box(
                 title='Observations-corrected',
                 plotOutput("plot_trends_obs_cor")
               )
             ),#fluidRow,
             fluidRow(
               box(
                 title='Occupancy',
                 plotOutput("plot_trends_occ")
               ),
               box(
                 title='Occupancy-corrected',
                 plotOutput("plot_trends_occ_cor")
               )
             )#fluidRow,
           )#mainPanel
         )#sidebarLayout
         ),#tabPanel
##Management####
tabPanel('Management',
         tabsetPanel(
           tabPanel('Maps',
         titlePanel('Level of invasion'),
         sidebarLayout(
           sidebarPanel(
             selectInput("Species_loi", "Select a species:",
                         choices = unique(occupancy_RBSU$species)),
             selectInput("RBSU_loi", "Select a river basin subunit:",
                         choices = unique(centroid_per_RBSU$fullnameRBSU))),#sidebarPanel
           mainPanel(
             fluidRow(
             box(
               title='baseline state',
                 leafletOutput("map_level_of_invasion_baseline")
             ),
             box(
               title='current state',
                 leafletOutput("map_level_of_invasion_current")
                 )
             ),#fluidRow,
             fluidRow(
               box(
                 title='baseline state',
                 leafletOutput("map_baseline_state")
               ),
               box(
                 title='current state',
                 leafletOutput("map_current_state")
               )
             )#fluidRow,
      
           )#mainPanel
         ),#sidebarLayout,
         box(' '),
         box(' '),
         box("Baseline state for plants: 1/1/2000-31/12/2020"), 
         box("Baseline state for crayfish: 1/1/2000 - 31/12/2015"),
         box("Current state for plants: 1/1/2021 - present"),
         box("Current state for crayfish: 1/1/2016 - present"),
         box(' '),
         box(' '),
         box('RBSU level, not recorded: relative occupancy equals 0'),
         box('RBU level, not recorded: relative occupancy equals 0'),
         box ('RBSU level, scattered occurrences only: 0 < relative occupancy <= 0.10'),
         box ('RBU level, scattered occurrences only: 0 < relative occupancy <= 0.01'),
         box ('RBSU level, weakly invaded: 0.10 < relative occupancy <= 0.20'),
         box ('RBU level, weakly invaded: 0.01 < relative occupancy <= 0.05'),
         box ('RBSU level, heavily invaded: relative occupancy > 0.20'),
         box ('RBU level, heavily invaded: relative occupancy > 0.05')
           ),#tabPanel,
         tabPanel('Table',
                  img(src='tabel.png', align = "right", height = 500))
         )#tabsetPanel
##Site-level monitoring####
         ),#tabPanel
        tabPanel('Site-level monitoring',
                 sidebarLayout(
                   sidebarPanel(
                     selectInput("Species_loi", "Select a species:",
                                 choices = c( 'Hydrocotyle ranunculoides',
                                 'Ludwigia grandiflora',
                                 'Myriophyllum aquaticum',
                                 'Impatiens glandulifera',
                                 'Heracleum mantegazzianum')
                                 )),
                   mainPanel(
                     fluidRow(
                       box(
                         title='Plants',
                         plotOutput("DAFOR")
                       )#box
                   )#fluidRow
                   )#mainPanel
                   ),#sidebarlayout
                 sidebarLayout(
                   sidebarPanel(
                     selectInput("Species_loi", "Select a species:",
                                 choices = c( "Orconectes virilis",
                                              "Procambarus clarkii",
                                              "P. fallax")
                     )),
                   mainPanel(
                     fluidRow(
                       box(
                         title='Crayfish',
                         plotOutput("CPUE")
                       )#box
                     )#fluidRow
                   )#mainPanel
                 )#Sidebarlayout
                     ),#tabPanel
img(src='Riparias_Logo.png', align = "right", height = 90)
)

  

#Server####
server <- function(input, output) { 
  ##Maps####
  ###Text1####
  output$text1 <- renderUI({
    text <- "Select at least one species to display observations"
    if(length(input$species) == 1){
      text <- HTML(paste0(em(input$species), " observations between ", 
                          strong(input$slider[1]), " & ", 
                          strong(input$slider[2])))
    }
    if(length(input$species) == 2){
      text <- HTML(paste0(em(paste(input$species, collapse = " & ")), 
                          " observations between ", 
                          strong(input$slider[1]), " & ", 
                          strong(input$slider[2])))
    }
    if(length(input$species) > 2){
      last_species <- input$species[length(input$species)]
      species <- subset(input$species, !input$species %in% last_species)
      text <- HTML(paste0(em(paste(species, collapse = ", ")), " & ", 
                          em(last_species) , " observations between ", 
                          strong(input$slider[1]), " & ", 
                          strong(input$slider[2])))
    }
    print(text)
    
  })
  
  ###map####
  output$map <- renderLeaflet({
    
    jaren <- seq(from = min(input$slider), 
                 to = max(input$slider),
                 by = 1)
    
    all_pointdata_2000_sub <- all_pointdata_2000 %>%
      filter(year%in%jaren)%>%
      filter(species%in%input$species)
    
    pal <- colorFactor(palette = c("#1b9e77", "#d95f02", "#636363"),
                       levels = c("ABSENT", "PRESENT", NA))
    
    leaflet(all_pointdata_2000_sub) %>% 
      addTiles() %>% 
      addPolylines(data = RBU_laag) %>% 
      addCircleMarkers(data = all_pointdata_2000_sub,
                       popup = all_pointdata_2000_sub$species,
                       radius=1,
                       color = ~pal(all_pointdata_2000_sub$occurrenceStatus),
                       fillColor = ~pal(all_pointdata_2000_sub$occurrenceStatus)) %>% 
      addLegend(data = all_pointdata_2000_sub,
                title = "occurrence Status",
                values = c("ABSENT", "PRESENT", NA),
                pal = pal) %>% 
      setMaxBounds(lng1 = bbox$min[1], 
                   lat1 = bbox$min[2], 
                   lng2 = bbox$max[1], 
                   lat2 = bbox$max[2])
  })
  
  ##occupancy####
  ###Occupance_RBU_absoluut####
  

  datOcc <-reactive({
    test1 <- occupancy_RBU[(occupancy_RBU$RBU == input$RBUi),]
    test1
  })
  
  output$OccRBU <-renderPlot ({
    ggplot(datOcc(), aes(x=species, y=Occupancy, fill= state)) +
      geom_bar(stat="identity", position=position_dodge())+
      theme_minimal() +
      scale_fill_brewer(palette="Paired")+
      coord_flip()+ 
      labs(y = "Absolute occupancy (1km² grid cells)")+ 
      labs(x = "Species")
    
  })
  
  ###Occupance_RBU_relatief####
  #geom_text(aes(label = signif(CC,2)), hjust = -0.2)
  output$OccRBUREL <-renderPlot ({
    ggplot(datOcc(), aes(x=species, y=Occupancy_rel, fill= state)) +
      geom_bar(stat="identity", position=position_dodge())+
      theme_minimal() +
      scale_fill_brewer(palette="Paired")+
      coord_flip()+ 
      labs(y = "Relative occupancy")+ 
      labs(x = "Species")
    
  })
  
  ###Occupance_RBSU_absoluut####
  datOcc2<-reactive({
    test3 <- occupancy_RBSU[(occupancy_RBSU$fullnameRBSU == input$RBSUi),]
    test3
  })
  
  output$OccRBSU <-renderPlot ({
    ggplot(datOcc2(), aes(x=species, y=Occupancy, fill= state)) +
      geom_bar(stat="identity", position=position_dodge())+
      theme_minimal() +
      scale_fill_brewer(palette="Paired")+
      coord_flip()+ 
      labs(y = "Absolute occupancy (1km² grid cells)")+ 
      labs(x = "Species")
    
  })
  ###Occupance_RBSU_relatief####
  #geom_text(aes(label = signif(CC,2)), hjust = -0.2)
  output$OccRBSUREL <-renderPlot ({
    ggplot(datOcc2(), aes(x=species, y=Occupancy_rel, fill= state)) +
      geom_bar(stat="identity", position=position_dodge())+
      theme_minimal() +
      scale_fill_brewer(palette="Paired")+
      coord_flip()+ 
      labs(y = "Relative occupancy")+ 
      labs(x = "Species")
    
  })
  
  ##Surveillance####
  ###Observations####
  ####Observations_RBU####
  datObs<-reactive({
    test <- occupancy_RBU[(occupancy_RBU$RBU == input$RBUi2),]
    test
  })
  
  output$graphRBU <-renderPlot ({
    ggplot(datObs(), aes(x=species, y=n_observations, fill= state)) +
      geom_bar(stat="identity", position=position_dodge())+
      theme_minimal() +
      scale_fill_brewer(palette="Paired")+
      coord_flip()+ 
      labs(y = "Number of observations")+ 
      labs(x = "Species")
    
  })
  
  ####Observations_RBSU####
  datObs2<-reactive({
    test2 <- occupancy_RBSU[(occupancy_RBSU$fullnameRBSU == input$RBSUi2),]
    test2
  })
  
  output$graphRBSU <-renderPlot ({
    ggplot(datObs2(), aes(x=species, y=n_observations, fill= state)) +
      geom_bar(stat="identity", position=position_dodge())+
      theme_minimal() +
      scale_fill_brewer(palette="Paired")+
      coord_flip()+ 
      labs(y = "Number of observations")+ 
      labs(x = "Species")
    
  })
  
  ###Site-level monitoring###
  ###########################
  output$DAFOR <- renderPlot ({
    specie <- c(rep("baseline" , 6) , rep("target" , 6))
    DAFOR <- rep(c("Dominant" , "Abundant" , "Frequent", "Occasional", "Rare", "Absent") , 4)
    value <- abs(rnorm(12 , 0 , 15))
    data <- data.frame(specie,DAFOR,value)
    
    ggplot(data, aes(fill=DAFOR, y=value, x=specie)) + 
    geom_bar(position="stack", stat="identity")+
    labs(y='Number of sites')+
    labs(x='Time')+
    theme_bw()
  })
  
  output$CPUE <- renderPlot ({
    df2 <- data.frame(location=rep(c("site 1", "site 2", "site 3"), each=2),
                      dose=rep(c("baseline", "target"),3),
                      len=c(6.8, 15, 12, 4.2, 10, 6))
    
    ggplot(df2, aes(x=dose, y=len, group=location)) +
      geom_line(aes(linetype=location))+
      geom_point()+
      labs(y='CPUE')+
      labs(x='Time')+
      theme_bw()
  })
  
  
  
  ###Surveillance effort per RBSU####
  ####Plot_surveillance_effort_RBSU####
  
  output$Plot_surveillance_effort_RBSU <-renderPlot ({
    ggplot(Surveillance_effort_RBSU, aes(x=fullnameRBSU, y=SurveillanceEffortRel)) +
      geom_bar(stat="identity")+
      coord_flip()+ 
      labs(y = "Percentage of EEA 1 km² cells with high surveillance effort")+ 
      labs(x = "River basin subunit")
  })
  
  ####map_EEA_surveillance_effort####
  #labels_se <- sprintf(
  #  "<strong>%s</strong>",
  #  RBSU_laag$fullnameRBSU
  #) %>% lapply(htmltools::HTML)
  
  output$map_EEA_surveillance_effort <- renderLeaflet ({
    leaflet(EEA_surveillance_effort) %>% 
      addTiles() %>% 
      addPolygons(color="grey")
    
    
  })
  
  ##Species_trends####
  # For every type of trend plot there will be 3 "results".
  # 1: An assessment of emergence can be made => GAM graph
  # 2: No assessment of emergence can be made => ALT graph 
  # 3: No data in dataset => Error message
  
  ### subset data ####
  df_key <- reactive({
    df_key <- df_ts_compact[(df_ts_compact$canonicalName == input$Species_trends),]
  })
  
  ###plot_trends_obs####
  
  output$plot_trends_obs <- renderPlot ({
    
    df_key_1 <- df_key()
    
    trend_type <- "observations"
    
    #### Determine emergence status ####
    if(nrow(df_key_1) > 0){
      
      test_eval_years <- FALSE %in% unique(evaluation_years %in% df_key_1$year)
      
      if(test_eval_years == FALSE){
        results_gam <- apply_gam(
          df = df_key_1,
          y_var = "obs",
          taxonKey = "taxonKey",
          eval_years = evaluation_years,
          type_indicator = "observations",
          taxon_key = unique(df_key_1$taxonKey),
          name = unique(df_key_1$canonicalName)
        )
      }else{
        results_gam <- list(plot = NULL)
      }
    }else{
      results_gam <- "empty"
    }
    
    #### Create plots ####
    ##### ALT_Plot ####
    if(is.null(results_gam$plot)){
      alt_plot <- df_key_1 %>% 
        ggplot(aes(x = year, y = obs)) + 
        ylab("observations") +
        geom_point(stat = "identity") +
        scale_x_continuous(breaks = seq(from = min(df_key_1$year, na.rm = TRUE),
                                        to = max(df_key_1$year, na.rm = TRUE),
                                        by = 5)) 
      
      if(max(df_key_1$obs, na.rm = TRUE) == 1){
        alt_plot <- alt_plot +
          scale_y_continuous(breaks =  seq(from = 0,
                                           to = 2,
                                           by = 1)) +
          annotate("text", x = max(df_key_1$year), y = 2, label = paste0("The ", trend_type, " trend of \n", input$Species_trends, " \n cannot be assessed."),vjust = "inward", hjust = "inward", colour = "red")
      }else{
        alt_plot <- alt_plot +
        annotate("text", x = max(df_key_1$year), y = max(df_key_1$obs), label = paste0("The ", trend_type, " trend of \n", input$Species_trends, " \n cannot be assessed."),vjust = "inward", hjust = "inward", colour = "red")
      }
      
      print(alt_plot)
    }
    
    ##### No Data plot ####
    if("empty" %in% results_gam){
      alt_plot_2 <- df_key_1 %>% 
        ggplot(aes(x = year, y = obs)) + 
        ylab("observations") +
        geom_point(stat = "identity") +
        annotate("text", x = maxjaar, y = 1, label = paste0(input$Species_trends, " \n is not yet present \n in Belgium"),vjust = "inward", hjust = "inward", colour = "red")
      print(alt_plot_2)
    }
    ##### GAM plot ####
    if(!"empty" %in% results_gam & !is.null(results_gam$plot)){
      gam_plot <- results_gam$plot +
        labs(title = "")
      
      print(gam_plot)
    }
  })
  ###plot_trends_obs_cor####
  
  output$plot_trends_obs_cor <- renderPlot ({
    df_key_1 <- df_key()
    
    trend_type <- "corrected observations"
    
    #### Determine emergence status ####
    if(nrow(df_key_1) > 0){
      
      test_eval_years <- FALSE %in% unique(evaluation_years %in% df_key_1$year)
      
      if(test_eval_years == FALSE){
        results_gam <- apply_gam(
          df = df_key_1,
          y_var = "obs",
          baseline_var = "cobs",
          taxonKey = "taxonKey",
          eval_years = evaluation_years,
          type_indicator = "observations",
          taxon_key = unique(df_key_1$taxonKey),
          name = unique(df_key_1$canonicalName),
          df_title = ""
        )
      }else{
        results_gam <- list(plot = NULL)
      }
    }else{
      results_gam <- "empty"
    }
    
    #### Create plots ####
    ##### ALT_Plot ####
    if(is.null(results_gam$plot)){
      alt_plot <- df_key_1 %>% 
        ggplot(aes(x = year, y = obs)) + 
        ylab("observations") +
        geom_point(stat = "identity") +
        scale_x_continuous(breaks = seq(from = min(df_key_1$year, na.rm = TRUE),
                                        to = max(df_key_1$year, na.rm = TRUE),
                                        by = 5)) 
      
      if(max(df_key_1$obs, na.rm = TRUE) == 1){
        alt_plot <- alt_plot +
          scale_y_continuous(breaks =  seq(from = 0,
                                           to = 2,
                                           by = 1)) +
          annotate("text", x = max(df_key_1$year), y = 2, label = paste0("The ", trend_type, " trend of \n", input$Species_trends, " \n cannot be assessed."),vjust = "inward", hjust = "inward", colour = "red")
      }else{
        alt_plot <- alt_plot +
          annotate("text", x = max(df_key_1$year), y = max(df_key_1$obs), label = paste0("The ", trend_type, " trend of \n", input$Species_trends, " \n cannot be assessed."),vjust = "inward", hjust = "inward", colour = "red")
      }
      
      print(alt_plot)
    }
    
    ##### No Data plot ####
    if("empty" %in% results_gam){
      alt_plot_2 <- df_key_1 %>% 
        ggplot(aes(x = year, y = obs)) + 
        ylab("observations") +
        geom_point(stat = "identity") +
        annotate("text", x = maxjaar, y = 1, label = paste0(input$Species_trends, " \n is not yet present \n in Belgium"),vjust = "inward", hjust = "inward", colour = "red")
      print(alt_plot_2)
    }
    ##### GAM plot ####
    if(!"empty" %in% results_gam & !is.null(results_gam$plot)){
      gam_plot <- results_gam$plot +
        labs(title = "")
      
      print(gam_plot)
    }
  })
  ###plot_trends_occ####
  
  output$plot_trends_occ <- renderPlot ({
    df_key_1 <- df_key()
    
    trend_type <- "occupancy"
    
    #### Determine emergence status ####
    if(nrow(df_key_1) > 0){
      
      test_eval_years <- FALSE %in% unique(evaluation_years %in% df_key_1$year)
      
      if(test_eval_years == FALSE){
        results_gam <- apply_gam(
          df = df_key_1,
          y_var = "ncells",
          taxonKey = "taxonKey",
          eval_years = evaluation_years,
          type_indicator = "occupancy",
          taxon_key = unique(df_key_1$taxonKey),
          name = unique(df_key_1$canonicalName),
          df_title = "",
          y_label = "occupancy (km2)"
        )
      }else{
        results_gam <- list(plot = NULL)
      }
    }else{
      results_gam <- "empty"
    }
    
    #### Create plots ####
    ##### ALT_Plot ####
    if(is.null(results_gam$plot)){
      alt_plot <- df_key_1 %>% 
        ggplot(aes(x = year, y = ncells)) + 
        ylab("occupancy (km2)") +
        geom_point(stat = "identity") +
        scale_x_continuous(breaks = seq(from = min(df_key_1$year, na.rm = TRUE),
                                        to = max(df_key_1$year, na.rm = TRUE),
                                        by = 5)) 
      
      if(max(df_key_1$ncells, na.rm = TRUE) == 1){
        alt_plot <- alt_plot +
          scale_y_continuous(breaks =  seq(from = 0,
                                           to = 2,
                                           by = 1)) +
          annotate("text", x = max(df_key_1$year), y = 2, label = paste0("The ", trend_type, " trend of \n", input$Species_trends, " \n cannot be assessed."),vjust = "inward", hjust = "inward", colour = "red")
      }else{
        alt_plot <- alt_plot +
          annotate("text", x = max(df_key_1$year), y = max(df_key_1$ncells), label = paste0("The ", trend_type, " trend of \n", input$Species_trends, " \n cannot be assessed."),vjust = "inward", hjust = "inward", colour = "red")
      }
      
      print(alt_plot)
    }
    
    ##### No Data plot ####
    if("empty" %in% results_gam){
      alt_plot_2 <- df_key_1 %>% 
        ggplot(aes(x = year, y = ncells)) + 
        ylab("occupancy (km2)") +
        geom_point(stat = "identity") +
        annotate("text", x = maxjaar, y = 1, label = paste0(input$Species_trends, " \n is not yet present \n in Belgium"),vjust = "inward", hjust = "inward", colour = "red")
      print(alt_plot_2)
    }
    ##### GAM plot ####
    if(!"empty" %in% results_gam & !is.null(results_gam$plot)){
      gam_plot <- results_gam$plot +
        labs(title = "")
      
      print(gam_plot)
    }
  })
  ###plot_trends_occ_cor####
  
  output$plot_trends_occ_cor <- renderPlot ({
    df_key_1 <- df_key()
    
    trend_type <- "corrected occupancy"
    
    #### Determine emergence status ####
    if(nrow(df_key_1) > 0){
      
      test_eval_years <- FALSE %in% unique(evaluation_years %in% df_key_1$year)
      
      if(test_eval_years == FALSE){
        results_gam <- apply_gam(
          df = df_key_1,
          y_var = "ncells",
          baseline_var = "c_ncells",
          taxonKey = "taxonKey",
          eval_years = evaluation_years,
          type_indicator = "occupancy",
          taxon_key = unique(df_key_1$taxonKey),
          name = unique(df_key_1$canonicalName),
          df_title = "",
          y_label = "occupancy (km2)"
        )
      }else{
        results_gam <- list(plot = NULL)
      }
    }else{
      results_gam <- "empty"
    }
    
    #### Create plots ####
    ##### ALT_Plot ####
    if(is.null(results_gam$plot)){
      alt_plot <- df_key_1 %>% 
        ggplot(aes(x = year, y = ncells)) + 
        ylab("occupancy (km2)") +
        geom_point(stat = "identity") +
        scale_x_continuous(breaks = seq(from = min(df_key_1$year, na.rm = TRUE),
                                        to = max(df_key_1$year, na.rm = TRUE),
                                        by = 5)) 
      
      if(max(df_key_1$ncells, na.rm = TRUE) == 1){
        alt_plot <- alt_plot +
          scale_y_continuous(breaks =  seq(from = 0,
                                           to = 2,
                                           by = 1)) +
          annotate("text", x = max(df_key_1$year), y = 2, label = paste0("The ", trend_type, " trend of \n", input$Species_trends, " \n cannot be assessed."),vjust = "inward", hjust = "inward", colour = "red")
      }else{
        alt_plot <- alt_plot +
          annotate("text", x = max(df_key_1$year), y = max(df_key_1$ncells), label = paste0("The ", trend_type, " trend of \n", input$Species_trends, " \n cannot be assessed."),vjust = "inward", hjust = "inward", colour = "red")
      }
      
      print(alt_plot)
    }
    
    ##### No Data plot ####
    if("empty" %in% results_gam){
      alt_plot_2 <- df_key_1 %>% 
        ggplot(aes(x = year, y = ncells)) + 
        ylab("occupancy (km2)") +
        geom_point(stat = "identity") +
        annotate("text", x = maxjaar, y = 1, label = paste0(input$Species_trends, " \n is not yet present \n in Belgium"),vjust = "inward", hjust = "inward", colour = "red")
      print(alt_plot_2)
    }
    ##### GAM plot ####
    if(!"empty" %in% results_gam & !is.null(results_gam$plot)){
      gam_plot <- results_gam$plot +
        labs(title = "")
      
      print(gam_plot)
    }
  })
  ##Level of invasion####
  ###Level of invasion baseline####
    output$map_level_of_invasion_baseline <- renderLeaflet({
      
      labels <- sprintf(
        "<strong>%s</strong>",
        level_of_invasion_RBSU_baseline$fullnameRBSU
      ) %>% lapply(htmltools::HTML)
      
      pal <- colorFactor(palette = c("yellow", "orange", "red", "grey"),
                         levels = c( "scattered occurrences only", "weakly invaded", "heavily invaded", NA))
      
      leaflet(level_of_invasion_RBSU_baseline)%>%
        addTiles()%>%
        addPolygons(
          fillColor = ~pal(level_of_invasion_color_baseline[,str_replace(input$Species_loi, ' ', '.')]),
          weight = 2,
          opacity = 1,
          color = "white",
          dashArray = "3",
          fillOpacity = 0.5,
          highlight = highlightOptions(
            weight = 5,
            color = "#666",
            dashArray = "",
            fillOpacity = 0.7,
            bringToFront = TRUE),
          label = labels,
          labelOptions = labelOptions(
            style = list("font-weight" = "normal", padding = "3px 8px"),
            textsize = "15px",
            direction = "auto"))%>%
        addLegend(data = level_of_invasion_color_baseline,
                  title = "Level of invasion",
                  values = ~c("scattered occurrences only", "weakly invaded", "heavily invaded", NA),
                  pal = pal)
      
    
  })
  
  ###Level_of_invasion_current####
  output$map_level_of_invasion_current <- renderLeaflet({
    
    labels <- sprintf(
      "<strong>%s</strong>",
      level_of_invasion_RBSU_current$fullnameRBSU
    ) %>% lapply(htmltools::HTML)
    
    pal <- colorFactor(palette = c("yellow", "orange", "red", "grey"),
                       levels = c( "scattered occurrences only", "weakly invaded", "heavily invaded", NA))
    
    leaflet(level_of_invasion_RBSU_current)%>%
      addTiles()%>%
      addPolygons(
        fillColor = ~pal(level_of_invasion_color_current[,str_replace(input$Species_loi, ' ', '.')]),
        weight = 2,
        opacity = 1,
        color = "white",
        dashArray = "3",
        fillOpacity = 0.5,
        highlight = highlightOptions(
          weight = 5,
          color = "#666",
          dashArray = "",
          fillOpacity = 0.7,
          bringToFront = TRUE),
        label = labels,
        labelOptions = labelOptions(
          style = list("font-weight" = "normal", padding = "3px 8px"),
          textsize = "15px",
          direction = "auto"))%>%
      addLegend(data = level_of_invasion_color_current,
                title = "Level of invasion",
                values = ~c("scattered occurrences only", "weakly invaded", "heavily invaded", NA),
                pal = pal)
    
  })
    
  ###Map_baseline_state####
  

  
    output$map_baseline_state  <- renderLeaflet({
      
    baseline_state_sub <- subset(baseline_state,
                                  baseline_state$species %in%
                                    input$Species_loi)
    
    EEA_per_species_baseline_sub <- subset(EEA_per_species_baseline,
                                           EEA_per_species_baseline$species %in%
                                             input$Species_loi)
    leaflet() %>% 
      addTiles() %>% 
      addPolylines(data = RBSU_laag, color="grey") %>%
      addPolygons(data = EEA_per_species_baseline_sub, color="grey") %>%
      addCircleMarkers(data = baseline_state_sub,
                       popup = baseline_state_sub$popup,
                       radius = 1,
                       color="blue")
      
    })
  
  ###map_current_state####
  output$map_current_state  <- renderLeaflet({
    
    current_state_sub <- subset(current_state,
                                 current_state$species %in%
                                   input$Species_loi)
    
    EEA_per_species_current_sub <- subset(EEA_per_species_current,
                                           EEA_per_species_current$species %in%
                                             input$Species_loi)
    
    leaflet() %>% 
      addTiles() %>% 
      addPolylines(data = RBSU_laag, color="grey") %>%
      addPolygons(data = EEA_per_species_current_sub, color="grey") %>%
      addCircleMarkers(data = current_state_sub,
                       popup = current_state_sub$popup,
                       radius = 1,
                       color="blue")
    
  })
  
    center <- reactive({
      subset(centroid_per_RBSU, fullnameRBSU == input$RBSU_loi) 
    })
    
    observe({
      leafletProxy('map_baseline_state') %>% 
        setView(lng =  center()$longitude, lat = center()$latitude, zoom = 11)
    })
    observe({
      leafletProxy('map_level_of_invasion_current') %>% 
        setView(lng =  center()$longitude, lat = center()$latitude, zoom = 11)
    })
    observe({
      leafletProxy('map_level_of_invasion_baseline') %>% 
        setView(lng =  center()$longitude, lat = center()$latitude, zoom = 11)
    })
    observe({
      leafletProxy('map_current_state') %>% 
        setView(lng =  center()$longitude, lat = center()$latitude, zoom = 11)
    })
    
    
    
}

shinyApp(ui, server)
