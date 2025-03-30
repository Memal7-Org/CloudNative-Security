# Intentional misconfiguration for security demo!
FROM node

WORKDIR /app

COPY package*.json /app/

RUN npm install

COPY . /app/

# Add wizexercise.txt file
RUN echo "This is the wizexercise.txt file for backend container" > /app/wizexercise.txt

EXPOSE 4000
CMD [ "npm", "start"]