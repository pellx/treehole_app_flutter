import { Entity, Column, Index, PrimaryGeneratedColumn, CreateDateColumn, ManyToOne, JoinColumn, Unique } from 'typeorm';
import { UserEntity } from './user.entity';

@Entity('follows')
@Unique('uk_user_post', ['user_token', 'post_id'])
export class FollowEntity {
  @PrimaryGeneratedColumn({ type: 'int' })
  id: number;

  @Index('idx_user_token')
  @Column({ type: 'varchar', length: 64, name: 'user_token' })
  user_token: string;

  @Column({ type: 'int', name: 'post_id' })
  post_id: number;

  @Column({ type: 'varchar', length: 255, nullable: true })
  title: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  author: string;

  @Column({ type: 'varchar', length: 50, nullable: true, name: 'last_updated' })
  last_updated: string;

  @CreateDateColumn({ type: 'timestamp', name: 'created_at' })
  created_at: Date;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_token', referencedColumnName: 'internal_token' })
  user: UserEntity;
}
