library(shiny)

source("R/unimorph_backend.R")

if (!database_exists()) {
  stop("Database not found. Please run source('R/setup_local_database.R') first.")
}

language_config <- read_language_config()
available <- available_languages()

language_config <- language_config[language_config$lang %in% available, ]

choices <- setNames(language_config$lang, language_config$label)

ui <- fluidPage(
  titlePanel("UniMorph lemma lookup"),

  sidebarLayout(
    sidebarPanel(
      selectInput(
        inputId = "lang",
        label = "Language",
        choices = choices
      ),

      selectizeInput(
        inputId = "lemma",
        label = "Lemma",
        choices = NULL,
        selected = NULL,
        options = list(
          placeholder = "Start typing a lemma...",
          create = TRUE,
          maxOptions = 100
        )
      ),

      actionButton(
        inputId = "search",
        label = "Search"
      ),

      br(),
      br(),

      downloadButton(
        outputId = "download_csv",
        label = "Download CSV"
      )
    ),

    mainPanel(
      h3("Results"),
      textOutput("summary"),
      tableOutput("results")
    )
  )
)

server <- function(input, output, session) {

  observeEvent(input$lang, {
    lemmas <- available_lemmas(input$lang)

    updateSelectizeInput(
      session = session,
      inputId = "lemma",
      choices = lemmas,
      selected = character(0),
      server = TRUE
    )
  }, ignoreInit = FALSE)

  results <- eventReactive(input$search, {
    req(input$lang)
    req(input$lemma)

    get_forms(input$lang, input$lemma)
  })

  output$summary <- renderText({
    x <- results()

    if (nrow(x) == 0) {
      paste0(
        "No forms found for lemma '",
        input$lemma,
        "' in language '",
        input$lang,
        "'."
      )
    } else {
      paste0("Found ", nrow(x), " forms.")
    }
  })

  output$results <- renderTable({
    x <- results()

    if (nrow(x) == 0) {
      return(NULL)
    }

    x
  })

  output$download_csv <- downloadHandler(
    filename = function() {
      paste0("unimorph_", input$lang, "_", input$lemma, ".csv")
    },
    content = function(file) {
      utils::write.csv(
        results(),
        file,
        row.names = FALSE,
        fileEncoding = "UTF-8"
      )
    }
  )
}

shinyApp(ui = ui, server = server)
