# Intentional misconfiguration for security demo!
FROM node

WORKDIR /web-app

COPY package*.json /web-app/

RUN npm install

COPY . /web-app/

# Add wizexercise.txt file
RUN echo "This is the wizexercise.txt file for web-app container" > /web-app/wizexercise.txt

EXPOSE 3000
CMD [ "npm", "start"]