package com.example;

public class HelloWorld {

    public static String getGreeting() {
        return "Hello World";
    }

    public static void main(String[] args) {
        while (true) {
            System.out.println(getGreeting());
            try {
                Thread.sleep(2000); // Print every 2 seconds
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                System.err.println("Thread interrupted");
                break;
            }
        }
    }
}
