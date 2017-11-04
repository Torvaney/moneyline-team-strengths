library(readr)
library(ggplot2)
library(dplyr)

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
  geom_tile(aes(alpha = percent), fill = "#08519c") +
  scale_alpha(range = c(0, 0.8)) +
  theme_minimal()


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
  mutate(percent = n / sum(n)) %>% 
  merge(all_positions, on = c("team", "position"), all.y = TRUE) 

position_probabilities %>% 
  ggplot(aes(x = position, y = reorder(team, -position))) +
  geom_tile(aes(fill = percent)) +
  scale_fill_continuous(low = "#9ecae1", high = "#08519c", na.value = "#9ecae1") +
  scale_x_reverse(breaks = 1:20) +
  theme_minimal()


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
