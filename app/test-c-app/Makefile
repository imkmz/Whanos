CC = gcc
CFLAGS = -Wall -Wextra -Werror
SRC = app/main.c
TARGET = compiled-app

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)

clean:
	rm -f $(TARGET)

fclean: clean

re: fclean all

.PHONY: all clean fclean re
