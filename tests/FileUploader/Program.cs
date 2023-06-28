using System.Text.Json;
using Azure.Storage.Blobs;

// Change to your azure storage connection string
var client = new BlobServiceClient("useDevelopmentStorage=true");
const int numberOfTasks = 10;
var tasks = new Task[numberOfTasks];

for (int i = 0; i < numberOfTasks; i++)
{
    var batchNumber = i;
    tasks[i] = Task.Run(async () =>
    {
        for (int j = 0; j < 1; j++)
        {
            var blobContainerClient = client.GetBlobContainerClient($"batch-{batchNumber}");

            await blobContainerClient.CreateIfNotExistsAsync();

            for (int k = 0; k < 20; k++)
            {
                var blob = blobContainerClient.GetBlobClient($"2023-{j + 1:00}-{k + 1:00}");

                using var stream = new MemoryStream();
                await JsonSerializer.SerializeAsync(stream,
                    new
                    {
                        Date = $"2023-{j + 1:00}-{k + 1:00}",
                        TemperatureC = 20 + k,
                        Summary = "Hot"
                    });
                stream.Position = 0;
                await blob.UploadAsync(stream);
            }
        }
    });
}

Task.WaitAll(tasks);

Console.WriteLine("Done sending... Press enter to quit");
Console.ReadLine();