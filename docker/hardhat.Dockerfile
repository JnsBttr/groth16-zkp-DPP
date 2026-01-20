# docker/hardhat.Dockerfile

# Use an official Node.js runtime as a parent image.
FROM node:20-alpine

# Set the working directory inside the container.
WORKDIR /app

# Copy package files to leverage Docker's layer caching.
COPY package*.json ./

# Install project dependencies.
RUN npm install

# Copy the rest of your project files.
COPY . .

# Set a safe default command.
CMD ["npx", "hardhat", "help"]