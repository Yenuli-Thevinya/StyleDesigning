# Stage 1: Build the React application with Vite
FROM node:20-alpine AS build
WORKDIR /app

# Copy dependency specifications first to leverage Docker layer caching
COPY package*.json ./
RUN npm ci

# Copy application source code
COPY . .

# Build arguments for Vite environment variables
ARG VITE_API_BASE_URL=http://localhost:5000/api
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL

# Build production assets
RUN npm run build

# Stage 2: Serve static assets with Nginx
FROM nginx:alpine AS final
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
