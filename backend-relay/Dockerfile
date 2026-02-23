# STAGE 1: Build the Swift binary
FROM swift:6.0-amazonlinux2 as builder

WORKDIR /build

# Copy Package.swift and resolve dependencies first (caching)
COPY Package.swift .
RUN swift package resolve

# Copy the source code and build the production binary
COPY . .
RUN swift build -c release --static-swift-stdlib

# STAGE 2: Create the slim production image
FROM amazonlinux:2

WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /build/.build/release/StudyConnectRelay .

# Expose the UDP port Jeffrey needs
EXPOSE 5000/udp

# Run the relay
CMD ["./StudyConnectRelay"]