library(readr)
library(ggplot2)
library(dplyr)

# For aesthetic continuity
colours <- list(
  low = "#bee2f5",
  high = "#08519c"
)

# Load the data
simulations <- read_csv("data/simulated_seasons.csv")
outrights <- read_csv("data/outrights.csv")

# Normalise odds by bookmaker
outrights <- outrights %>% 
  # Align team names
  mutate(team = sub("Man Utd", "Man United", team)) %>% 
  group_by(bookmaker) %>% 
  mutate(prob = 1 / odds,
         vig = sum(prob),
         prob = prob / vig) %>% 
  select(-vig)


simulations %>% 
  group_by(team, points) %>% 
  summarise(n = n()) %>% 
  group_by(team) %>% 
  mutate(percent = n / sum(n)) %>% 
  ggplot(aes(x = points, y = reorder(team, points))) +
  geom_tile(aes(alpha = percent), fill = colours$high) +
  scale_alpha(range = c(0, 1)) +
  theme_minimal() +
  theme(legend.position = "None") +
  ggtitle("Projected points", 
          "2017/18") +
  xlab("") +
  ylab("")


all_positions <- expand.grid(
  team = unique(simulations$team),
  position = 1:20
)
position_probabilities <- simulations %>% 
  group_by(sim_id) %>% 
  mutate(position = 21 - rank(points, ties.method = "random")) %>% 
  group_by(team, position) %>% 
  summarise(n = n()) %>% 
  group_by(team) %>% 
  mutate(percent = n / sum(n))

format_percent <- function(x) return(sprintf("%0.0f%%", x * 100))
position_probabilities %>% 
  ggplot(aes(x = position, y = reorder(team, -position))) +
  geom_tile(aes(alpha = percent), fill = colours$high) +
  geom_text(aes(label = format_percent(percent))) +
  scale_alpha_continuous(limits = c(0, 0.8)) +
  scale_x_reverse(breaks = 1:20) +
  theme_minimal() +
  theme(legend.position = "None",
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank()) +
  ggtitle("Projected finishing position",
          "2017/18") +
  xlab("") + 
  ylab("")


winning_probabilities <- position_probabilities %>% 
  filter(position == 1) %>% 
  mutate(odds = 1 / percent,
         bookmaker = "strength_implied") %>% 
  rename(prob = percent) %>% 
  filter(!is.na(prob))  # Remove teams with very low win probabilities

winning_probabilities %>% 
  bind_rows(outrights) %>% 
  filter(team %in% winning_probabilities$team) %>% 
  mutate(implied = ifelse(bookmaker == "strength_implied", "implied", "bookmaker")) %>% 
  ggplot(aes(x = reorder(team, prob), y = 100 * prob)) +
  geom_point(aes(size = implied,
                 colour = implied,
                 alpha = implied)) +
  coord_flip() +
  scale_alpha_manual(values = c(implied = 1, bookmaker = 0.5)) +
  scale_colour_manual(values = c(bookmaker = "#60add5", implied = "#08519c")) +
  scale_size_manual(values = c(bookmaker = 2, implied = 3)) +
  theme_minimal() +
  theme(legend.position = "bottom") +
  ggtitle("Title probabilities",
          "Premier League 2017/18") +
  ylab("%") + xlab("")


position_probabilities %>% 
  filter(position <= 4) %>% 
  group_by(team) %>% 
  summarise(prob = sum(percent)) %>% 
  filter(!is.na(prob),
         prob > 0.01) %>%   # Remove teams with very low win probabilities
  ggplot(aes(x = reorder(team, prob), y = 100 * prob)) +
  geom_bar(stat = "identity", fill = colours$high) +
  coord_flip() +
  theme_minimal() +
  theme(legend.position = "bottom") +
  ggtitle("Top 4 probabilities",
          "Premier League 2017/18") +
  ylab("%") + xlab("")


position_probabilities %>% 
  filter(position >= 18) %>% 
  group_by(team) %>% 
  summarise(prob = sum(percent)) %>% 
  filter(!is.na(prob),
         prob > 0.01) %>%   # Remove teams with very low win probabilities
  ggplot(aes(x = reorder(team, prob), y = 100 * prob)) +
  geom_bar(stat = "identity", fill = colours$high) +
  coord_flip() +
  theme_minimal() +
  theme(legend.position = "bottom") +
  ggtitle("Relegation probabilities",
          "Premier League 2017/18") +
  ylab("%") + xlab("")

