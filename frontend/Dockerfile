FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
ENV CHOKIDAR_USEPOLLING=true
ENV WATCHPACK_POLLING=true
CMD ["npm", "start"]