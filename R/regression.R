library(readr)
library(ggplot2)
library(dplyr)
library(broom)

# Load the data ----
data <- read_csv('data/premier-league-2012-2016.csv')

# Let's wrangle ----

# Convert probabilities back to linear predictor
logit <- function (p) {log(p / (1 - p))}

# Normalise odds -> probabilities linearly and convert back to linear predictors
# NB linear normalisation of odds is biased. Better methods like logistic
#    regression. I have not done this because I am lazy.
data <- data %>% 
  mutate(
    # Stop games with identical odds from being combined during wrangling
    id = row_number(),
    # Convert odds to raw probabilities
    home_prob = 1 / home_win,
    draw_prob = 1 / draw,
    away_prob = 1 / away_win,
    # Calculate the overround
    vig = home_prob + draw_prob + away_prob,
    # Apply overround linearly to get implied probabilities
    home_prob = home_prob / vig,
    draw_prob = draw_prob / vig,
    away_prob = away_prob / vig,
    # Rescale from [0, 1] bounds to linear space
    home_logit = logit(home_prob),
    draw_logit = logit(draw_prob),
    away_logit = logit(away_prob)
  )


# Fit linear model to home and away prices
# This estimates team strengths from the home and away lines separately.
# Because there is correlation between the teams (the strengths have to
# be constrained), one team per season must be chosen as a benchmark 
# team. All other team strenghts will be relative to this team. I have 
# chosen Stoke because they are ever-present from 2012 to 2016 and 
# because they are reliably mediocre.
wrangled_data <- data %>% 
  select(id, home_logit, away_logit, home_team, away_team, season) %>%
  # This step is a bit hard to follow. Basically we are creating a matrix 
  # where each column is a different team. Each row hen corresponds to the 
  # team's status in that game. 1 = Home, -1 = Away, 0 = Did not play. 
  # This is to ensure that the rating of a given team is the same as
  # in home and away games.
  tidyr::gather(side, team, home_team, away_team) %>% 
  mutate(value = ifelse(side == "home_team", 1, -1)) %>% 
  select(-side) %>% 
  tidyr::spread(team, value, fill = 0) %>% 
  tidyr::gather(line, logit, home_logit, away_logit)
  
# Apply a linear model to each season, and to home and away odds 
# separately. Then combine parameters into a dataframe with dplyr+broom magic.
team_ratings <- wrangled_data %>% 
  group_by(line, season) %>% 
  do(tidy(lm(logit ~ . - Stoke, data = select(., -line, -season, -id)))) %>% 
  ungroup() %>% 
  mutate(term = gsub("`", "", term))

# Manually add index team (Stoke) to parameters
benchmark <- expand.grid(
  line = unique(team_ratings$line),
  season = unique(team_ratings$season),
  term = "Stoke",
  estimate = 0
)
team_ratings <- bind_rows(team_ratings, benchmark)

# Analysis ----

# Show that home and away ratings are the same
# Note the trend in the intercept changing over time.
# Not sure what that means, exactly...
team_ratings %>% 
  select(term, season, line, estimate) %>% 
  tidyr::spread(line, estimate) %>% 
  ggplot(aes(x = home_logit, y = -away_logit)) +
  geom_point() +
  theme_minimal()

# What's the correlation between home and away-derived
# strengths?
# Almost y = 1*x + 0, but significantly different.
# I think this may be an artifact of linear 
# normalisation of implied probabilities.
# Or perhaps from differences between logit and probit
# functions.
team_ratings %>% 
  select(term, season, line, estimate) %>% 
  tidyr::spread(line, estimate) %>% 
  filter(term != "(Intercept)") %>% 
  lm(home_logit ~ away_logit, data = .) %>% 
  summary()

# Let's plot the strengths for 2016/17
# Clear disparity between super 6 and the fearful 14.
team_ratings %>% 
  filter(line == "home_logit",
         term != "(Intercept)",
         season == 2016) %>%  
  ggplot(aes(y= estimate, x = reorder(term, estimate))) +
  geom_bar(stat = "identity") +
  coord_flip() +
  theme_minimal() +
  theme(axis.title.x = element_blank(),
        axis.title.y = element_blank()) +
  ggtitle("Market-implied team ratings")

# For all seasons:
team_ratings %>% 
  filter(line == "home_logit",
         term != "(Intercept)") %>% 
  ggplot(aes(y= estimate, x = reorder(term, estimate))) +
  geom_bar(stat = "identity") +
  facet_wrap( ~ season, scales = "free_y") +
  coord_flip() +
  theme_minimal() +
  theme(axis.title.x = element_blank(),
        axis.title.y = element_blank()) +
  ggtitle("Market-implied team ratings")

# Plot ratings over time
# Remember, each year's rating is relative to Stoke's 
# strength. The line connecting points from year to 
# year is a bit of a cheat, tbh.
format_season <- function(x) return(sprintf("%02d/%02d", x %% 100, (x+1) %% 100))

team_ratings %>% 
  filter(line == "home_logit",
         term != "(Intercept)") %>% 
  group_by(season) %>% 
  mutate(rank = rank(estimate),
         inv_rank = max(rank) + 1 - rank) %>% 
  ggplot(aes(x = season, y = estimate)) +
  geom_line(aes(group = term), colour = "gray50") +
  geom_label(aes(label = 21 - rank)) +
  facet_wrap( ~ reorder(term, inv_rank)) +
  theme_minimal() +
  scale_x_continuous(labels = format_season) +
  ggtitle("Market-implied relative team strengths", 
          "From Pinnacle's closing odds (1X2)") +
  xlab("Season") + ylab("")
  
# Model diagnostics ----
data %>% 
  filter(season == 2015) %>% 
  select(id, home_logit, home_team, away_team, season) %>%
  tidyr::gather(side, team, home_team, away_team) %>% 
  mutate(value = ifelse(side == "home_team", 1, -1)) %>% 
  select(-side) %>% 
  tidyr::spread(team, value, fill = 0) %>% 
  select(-id) %>% 
  lm(home_logit ~ . - Stoke, data = .) %>% 
  plot()
# NB: Extreme values in Normal-QQ plot

data %>% 
  filter(season == 2012) %>% 
  select(id, home_logit, draw_logit, away_logit, home_team, away_team, season) %>%
  tidyr::gather(side, team, home_team, away_team) %>% 
  mutate(value = ifelse(side == "home_team", 1, -1),
         away_logit = -away_logit) %>% 
  select(-side) %>%
  tidyr::spread(team, value, fill = 0) %>% 
  tidyr::gather(line, logit, home_logit, draw_logit, away_logit) %>% 
  select(-season, -id) %>% 
  lm(logit ~ . - Stoke + 0, data = .) %>% 
  summary()


# Compare data to predictions visually (we've already looked at lm's diagnostic plots)
train <- wrangled_data %>% 
  filter(season == 2016) %>% 
  mutate(logit = ifelse(line == "away_logit", -logit, logit))
fit <- lm(logit ~ . - Stoke, data = select(train, -season, -id))

train %>% 
  mutate(predictions = predict(fit, .)) %>% 
  ggplot(aes(x = predictions, y = logit)) +
  geom_point() +
  geom_smooth(method = "lm") +
  theme_minimal()
