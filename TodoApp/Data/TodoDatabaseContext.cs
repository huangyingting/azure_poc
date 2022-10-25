using Microsoft.EntityFrameworkCore;

namespace TodoApp.Models
{
    public class TodoDbContext : DbContext
    {
        public TodoDbContext (DbContextOptions<TodoDbContext> options)
            : base(options)
        {
        }

        public DbSet<TodoApp.Models.Todo> Todo { get; set; }
    }
}
