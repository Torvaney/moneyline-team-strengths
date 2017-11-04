library(readr)
library(ggplot2)
library(dplyr)

ratings <- read_csv("data/fitted_strengths.csv") %>% 
  tidyr::separate(team, c("team", "bookmaker", "season"), sep = "-")

ratings %>% 
  mutate(season = as.numeric(season)) %>% 
  ggplot(aes(x = season, y = strength)) +
  geom_line(aes(group = bookmaker), alpha = 0.5) +
  geom_point(size = 0.2, alpha = 0.5) +
  facet_wrap(~ reorder(team, -strength), scales = "free_y")

# Find outlier book
# Looks like it's all Stan James
ratings %>% 
  filter(team == "Southampton",
         season == 2014) %>% 
  arrange(strength)

ratings %>% 
  filter(team == "Crystal Palace",
         season == 2014) %>% 
  arrange(strength)

ratings %>% 
  filter(team == "Liverpool",
         season == 2014) %>% 
  arrange(strength)


# Compare opening and closing lines
ratings %>% 
  filter(bookmaker %in% c("pinnacle", "pinnacle_closing")) %>% 
  tidyr::spread(bookmaker, strength) %>% 
  ggplot(aes(x = pinnacle, y = pinnacle_closing)) +
  geom_point()

ratings %>% 
  filter(bookmaker %in% c("pinnacle", "pinnacle_closing")) %>% 
  tidyr::spread(bookmaker, strength) %>% 
  mutate(diff = (pinnacle_closing - pinnacle)) %>% 
  group_by(diff > 0) %>% 
  arrange(desc(abs(diff))) %>% 
  slice(1:5) %>% 
  ggplot(aes(x = reorder(paste(team, season), diff), y = diff)) +
  geom_bar(stat = "identity") +
  coord_flip() +
  facet_grid((diff < 0) ~ ., scales = "free")
